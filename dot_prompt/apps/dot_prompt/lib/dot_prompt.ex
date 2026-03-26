defmodule DotPrompt do
  @moduledoc """
  Main API for dot-prompt.
  """
  require Logger

  alias DotPrompt.Parser.{Lexer, Parser, Validator}
  alias DotPrompt.Compiler.{CaseResolver, IfResolver, VaryCompositor, ResponseCollector}
  alias DotPrompt.Compiler.FragmentExpander.Collection, as: FragmentCollection
  alias DotPrompt.Compiler.FragmentExpander.Dynamic, as: FragmentDynamic
  alias DotPrompt.Compiler.FragmentExpander.Static, as: FragmentStatic
  alias DotPrompt.Cache.{Fragment, Structural, Vary}
  alias DotPrompt.Injector
  alias DotPrompt.Telemetry

  @type prompt_name :: String.t()
  @type params :: map()
  @type runtime :: map()
  @type compile_opts :: [
          indent: integer(),
          seed: integer()
        ]

  @type schema_info :: %{
          name: prompt_name(),
          version: integer(),
          description: String.t() | nil,
          mode: String.t() | nil,
          docs: String.t() | nil,
          params: map(),
          fragments: map()
        }

  @doc "Lists all available prompts including fragments."
  @spec list_prompts() :: [prompt_name()]
  def list_prompts do
    path = prompts_dir()

    if File.exists?(path) do
      "#{path}/**/*.prompt"
      |> Path.wildcard()
      |> Enum.map(fn full_path ->
        full_path
        |> Path.relative_to(path)
        |> String.replace_suffix(".prompt", "")
      end)
      |> Enum.sort()
    else
      []
    end
  end

  @doc "Lists only root-level prompts (excluding fragments)."
  @spec list_root_prompts() :: [prompt_name()]
  def list_root_prompts do
    list_prompts()
    |> Enum.reject(&String.contains?(&1, "/"))
  end

  @doc "Lists only fragment prompts."
  @spec list_fragment_prompts() :: [prompt_name()]
  def list_fragment_prompts do
    list_prompts()
    |> Enum.filter(&String.contains?(&1, "/"))
    |> Enum.sort()
  end

  def list_collections do
    path = prompts_dir()

    if File.exists?(path) do
      File.ls!(path)
      |> Enum.filter(&File.dir?(Path.join(path, &1)))
      |> Enum.reject(&String.starts_with?(&1, "_"))
    else
      []
    end
  end

  @doc "Extracts the schema and metadata for a given prompt."
  @spec schema(prompt_name(), integer() | nil) :: {:ok, schema_info()} | {:error, map()}
  def schema(prompt_name, major \\ nil) do
    prompts_dir = prompts_dir()

    {mtime, _path_for_cache} =
      if is_binary(prompt_name) and !String.contains?(prompt_name, "\n") and
           !String.contains?(prompt_name, " ") do
        p = Path.join(prompts_dir, prompt_name <> ".prompt")
        {if(File.exists?(p), do: File.stat!(p).mtime, else: 0), p}
      else
        {0, nil}
      end

    case Fragment.get({:schema, to_string(prompt_name), major, mtime}) do
      {:ok, result} ->
        {:ok, result}

      _ ->
        try do
          {_content, actual_mtime, path} = load_prompt_file_with_meta(prompt_name, major)
          do_parse_schema(prompt_name, path, actual_mtime, major)
        rescue
          _ ->
            {:error,
             %{
               error: "prompt_not_found",
               message: "Could not find prompt #{prompt_name} (major: #{major || "latest"})"
             }}
        end
    end
  end

  defp do_parse_schema(prompt_name, path, mtime, major) do
    try do
      content = File.read!(path)
      tokens = Lexer.tokenize(content)

      case Parser.parse(tokens) do
        {:error, message} ->
          {:error, %{error: "syntax_error", message: message}}

        {:ok, ast} ->
          params = Validator.parse_param_declarations_for_schema(ast.init)
          def_block = Validator.parse_def_block(ast.init)
          docs = Validator.parse_docs_block(ast.init)
          fragments = Validator.parse_fragment_declarations(ast.init)

          schema_params =
            Enum.into(params, %{}, fn {name, spec} ->
              clean_name = name |> to_string() |> String.trim_leading("@")

              spec_map =
                %{type: spec.type, lifecycle: spec.lifecycle, doc: spec.doc}
                |> maybe_put(:default, spec[:default])
                |> maybe_put(:values, spec[:values])
                |> maybe_put(:range, spec[:range])

              {clean_name, spec_map}
            end)

          schema_fragments =
            Enum.into(fragments, %{}, fn {name, spec} ->
              clean_name =
                name
                |> to_string()
                |> String.trim_leading("{")
                |> String.trim_trailing("}")

              spec_map =
                %{type: spec.type, doc: spec.doc}
                |> maybe_put(:from, spec[:from])

              {clean_name, spec_map}
            end)

          # Merge def_block to ensure Match/MatchRe and other metadata are present
          result =
            Map.merge(def_block, %{
              name: to_string(prompt_name),
              major: major_from_version(def_block[:version]),
              version: def_block[:version] || 1,
              params: schema_params,
              fragments: schema_fragments,
              docs: docs
            })

          Fragment.put({:schema, to_string(prompt_name), major, mtime}, result)
          {:ok, result}
      end
    rescue
      e ->
        {:error, %{error: "parsing_failed", message: inspect(e)}}
    end
  end

  @doc """
  Compiles a prompt for given params.
  Returns {:ok, %DotPrompt.Result{}} or {:error, map()}
  """
  @spec compile(prompt_name() | String.t(), params(), compile_opts()) ::
          {:ok, DotPrompt.Result.t()} | {:error, map()}
  def compile(prompt_name_or_content, params, opts \\ []) do
    case compile_to_iodata(prompt_name_or_content, params, opts) do
      {:ok, skeleton_iodata, final_selections, used_vars, cached_files_meta, hit, warnings,
       response_contract, major, version, declarations} ->
        skeleton = IO.iodata_to_binary(skeleton_iodata)

        # Clean @ from parameter keys for the response, but keep @version and @major as meta
        clean_params =
          Enum.into(declarations, %{}, fn {k, v} ->
            if k in ["@version", "@major"] do
              {k, v}
            else
              {String.trim_leading(k, "@"), v}
            end
          end)

        result = %DotPrompt.Result{
          prompt: skeleton,
          response_contract: response_contract,
          vary_selections: final_selections,
          compiled_tokens: count_tokens(skeleton),
          cache_hit: hit,
          major: major,
          version: version,
          metadata: %{
            used_vars: used_vars,
            files: cached_files_meta,
            warnings: warnings,
            params: clean_params
          }
        }

        {:ok, result}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Internal compile that returns iodata for maximum efficiency when nesting fragments.
  """
  @spec compile_to_iodata(prompt_name() | String.t(), params(), compile_opts()) ::
          {:ok, iodata(), map(), MapSet.t(), map(), boolean(), [String.t()], map() | nil,
           integer(), integer() | String.t(), map()}
          | {:error, map()}
  def compile_to_iodata(prompt_name_or_content, params, opts \\ []) do
    annotated = Keyword.get(opts, :annotated, false)
    start_time = System.monotonic_time()

    # Normalize params to use atom keys
    params = Enum.into(params, %{}, fn {k, v} -> {ensure_atom(k), v} end)

    Telemetry.start_render(to_string(prompt_name_or_content), params)

    content_ref =
      if String.contains?(prompt_name_or_content, "\n") or
           String.contains?(prompt_name_or_content, " ") do
        {:inline, prompt_name_or_content}
      else
        {:file, to_string(prompt_name_or_content)}
      end

    prompt_key =
      case content_ref do
        {:inline, _} -> :inline
        {:file, name} -> name
      end

    {content, files_meta} =
      if String.contains?(prompt_name_or_content, "\n") or
           String.contains?(prompt_name_or_content, " ") do
        {prompt_name_or_content, %{}}
      else
        major = Keyword.get(opts, :major)
        {content, mtime, path} = load_prompt_file_with_meta(prompt_name_or_content, major)
        {content, %{path => mtime}}
      end

    cache_key = cache_key_for_compile(prompt_key, params, content, annotated)

    case Structural.get(cache_key) do
      {:ok, {skeleton_iodata, vary_map, used_vars, cached_files_meta, major, version, declarations}} ->
        if stale?(cached_files_meta) do
          # Stale cache, proceed with fresh compilation
          compile_fresh_with_content(
            prompt_name_or_content,
            content,
            files_meta,
            params,
            opts,
            start_time,
            cache_key
          )
        else
          duration = System.monotonic_time() - start_time

          # Convert iodata to binary for resolution and token counting
          skeleton_binary = IO.iodata_to_binary(skeleton_iodata)

          {output_skeleton, final_selections} =
            if annotated do
              # We still want selections for DevUI labels
              {_resolved, selections} =
                VaryCompositor.resolve_full(skeleton_binary, vary_map, opts[:seed], params)

              {skeleton_iodata, selections}
            else
              {resolved, selections} =
                VaryCompositor.resolve_full(skeleton_binary, vary_map, opts[:seed], params)

              {strip_annotations(resolved), selections}
            end

          compiled_tokens = count_tokens(output_skeleton)

          Telemetry.stop_render(
            to_string(prompt_name_or_content),
            params,
            System.convert_time_unit(duration, :native, :millisecond),
            %{
              compiled_tokens: compiled_tokens,
              vary_selections: final_selections,
              cache_hit: true
            }
          )

          # Extract contract from cache
          response_contract =
            case Structural.get({:contract, cache_key}) do
              {:ok, contract} -> contract
              _ -> nil
            end

          {:ok, output_skeleton, final_selections, used_vars, cached_files_meta, true, [],
           response_contract, major, version, declarations}
        end

      {:ok, {_skeleton_iodata, _vary_map, _used_vars, _cached_files_meta, _major, _version}} ->
        # Handle legacy cache format without declarations
        compile_fresh_with_content(
          prompt_name_or_content,
          content,
          files_meta,
          params,
          opts,
          start_time,
          cache_key
        )

      # Handle legacy cache format or miss
      _ ->
        compile_fresh_with_content(
          prompt_name_or_content,
          content,
          files_meta,
          params,
          opts,
          start_time,
          cache_key
        )
    end
  end

  defp compile_fresh_with_content(
         prompt_name_or_content,
         content,
         files_meta,
         params,
         opts,
         start_time,
         cache_key
       ) do
    annotated = Keyword.get(opts, :annotated, false)
    tokens = Lexer.tokenize(content)

    case Parser.parse(tokens) do
      {:error, message} ->
        handle_parsing_error(prompt_name_or_content, params, start_time, message, tokens)

      {:ok, ast} ->
        case Validator.validate(ast) do
          {:ok, warnings} ->
            process_valid_ast(
              prompt_name_or_content,
              content,
              files_meta,
              params,
              opts,
              start_time,
              cache_key,
              annotated,
              ast,
              warnings
            )

          {:error, reason} ->
            handle_validation_error(prompt_name_or_content, params, start_time, reason, content)
        end
    end
  end

  defp handle_parsing_error(prompt_name, params, start_time, message, tokens) do
    error_msg = extract_error_with_line(message, tokens)
    Logger.error("dot-prompt compilation error: #{error_msg}")

    Telemetry.stop_render(
      to_string(prompt_name),
      params,
      System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond),
      %{compiled_tokens: 0}
    )

    {:error, %{error: "syntax_error", message: error_msg}}
  end

  defp handle_validation_error(prompt_name, params, start_time, reason, content) do
    reason_with_line = add_line_info_to_validation_error(reason, content)
    Logger.error("dot-prompt validation error: #{reason_with_line}")

    Telemetry.stop_render(
      to_string(prompt_name),
      params,
      System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond),
      %{compiled_tokens: 0}
    )

    {:error, %{error: "validation_error", message: reason_with_line}}
  end

  defp process_valid_ast(
         prompt_name_or_content,
         content,
         files_meta,
         params,
         opts,
         start_time,
         cache_key,
         annotated,
         ast,
         warnings
       ) do
    init = ast.init || %{params: %{}, fragments: %{}, docs: nil}
    declarations = Validator.parse_param_declarations_for_schema(init)
    params_with_defaults = apply_defaults(params, declarations)

    case validate_params_if_needed(params_with_defaults, declarations) do
      :ok ->
        fragment_defs = Validator.parse_fragment_declarations(init)
        indent_start = opts[:indent] || 0

        case handle_response_contracts(ast.body, warnings) do
          {:error, msg} ->
            {:error, %{error: "validation_error", message: msg}}

          {:ok, warnings, first_schema} ->
            compile_and_build_result(
              prompt_name_or_content,
              content,
              params,
              opts,
              start_time,
              cache_key,
              annotated,
              ast,
              warnings,
              params_with_defaults,
              fragment_defs,
              indent_start,
              files_meta,
              declarations,
              first_schema
            )
        end

      {:error, reason} ->
        handle_validation_error(
          prompt_name_or_content,
          params,
          start_time,
          reason,
          content
        )
    end
  end

  defp handle_response_contracts(body, warnings) do
    response_blocks = ResponseCollector.collect_response_blocks(body)

    schemas =
      Enum.map(response_blocks, fn {content, _line} ->
        ResponseCollector.derive_schema(content)
      end)

    comparison = ResponseCollector.compare_schemas(schemas)

    case comparison do
      :incompatible ->
        {:error, "incompatible_contracts: response blocks have incompatible schemas"}

      _ ->
        first_schema = Enum.at(schemas, 0)

        maybe_warn =
          if comparison == :compatible,
            do: ["compatible_contracts: response blocks have same fields but different values"],
            else: []

        {:ok, warnings ++ maybe_warn, first_schema}
    end
  end

  defp compile_and_build_result(
         prompt_name_or_content,
         content,
         params,
         opts,
         start_time,
         cache_key,
         annotated,
         ast,
         warnings,
         params_with_defaults,
         fragment_defs,
         indent_start,
         files_meta,
         declarations,
         first_schema
       ) do
    case compile_ast(
           ast.body,
           params_with_defaults,
           fragment_defs,
           %{},
           MapSet.new(),
           indent_start,
           files_meta,
           0,
           declarations
         ) do
      {:error, reason} ->
        reason_with_line = add_line_info_to_validation_error(reason, content)
        Logger.error("dot-prompt compilation error: #{reason_with_line}")

        Telemetry.stop_render(
          to_string(prompt_name_or_content),
          params,
          System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond),
          %{compiled_tokens: 0}
        )

        {:error, %{error: "validation_error", message: reason_with_line}}

      {skeleton_iodata, vary_map, used_vars, total_files_meta, _count} ->
        seed = opts[:seed]
        def_info = Validator.parse_def_block(ast.init)
        version = def_info[:version] || 1
        major = major_from_version(version)

        skeleton_binary = IO.iodata_to_binary(skeleton_iodata)

        skeleton_binary =
          if first_schema do
            schema_json = Jason.encode!(first_schema, pretty: true)
            String.replace(skeleton_binary, "{response_contract}", schema_json)
          else
            skeleton_binary
          end

        {output_skeleton, vary_selections} =
          resolve_and_strip(skeleton_binary, vary_map, seed, params_with_defaults, annotated)

        Structural.put(
          cache_key,
          {skeleton_iodata, vary_map, used_vars, total_files_meta, major, version, declarations}
        )

        if first_schema do
          Structural.put({:contract, cache_key}, first_schema)
        end

        duration = System.monotonic_time() - start_time
        compiled_tokens = count_tokens(output_skeleton)

        Telemetry.stop_render(
          to_string(prompt_name_or_content),
          params,
          System.convert_time_unit(duration, :native, :millisecond),
          %{
            compiled_tokens: compiled_tokens,
            vary_selections: vary_selections,
            cache_hit: false
          }
        )

        {:ok, output_skeleton, vary_selections, used_vars, total_files_meta, false, warnings,
         first_schema, major, version, declarations}
    end
  end

  defp resolve_and_strip(skeleton_binary, vary_map, seed, params, true) do
    {_resolved, selections} =
      VaryCompositor.resolve_full(skeleton_binary, vary_map, seed, params)

    {skeleton_binary, selections}
  end

  defp resolve_and_strip(skeleton_binary, vary_map, seed, params, false) do
    {resolved, selections} =
      VaryCompositor.resolve_full(skeleton_binary, vary_map, seed, params)

    {strip_annotations(resolved), selections}
  end

  def inject(template, runtime) do
    Injector.inject(template, runtime)
  end

  @doc """
  Renders a prompt by compiling it and injecting runtime data.
  """
  @spec render(prompt_name() | String.t(), params(), runtime(), compile_opts()) ::
          {:ok, DotPrompt.Result.t()} | {:error, map()}
  def render(prompt_name_or_content, params, runtime, opts \\ []) do
    # Normalize params/runtime to use atom keys
    params = Enum.into(params, %{}, fn {k, v} -> {ensure_atom(k), v} end)
    runtime = Enum.into(runtime, %{}, fn {k, v} -> {ensure_atom(k), v} end)

    case compile(prompt_name_or_content, params, opts) do
      {:ok, %DotPrompt.Result{} = compile_result} ->
        result_prompt = inject(compile_result.prompt, runtime)
        injected_tokens = count_tokens(result_prompt)

        final_result = %{
          compile_result
          | prompt: result_prompt,
            injected_tokens: injected_tokens
        }

        {:ok, final_result}

      {:error, _} = error ->
        error
    end
  end

  defp ensure_atom(k) when is_atom(k), do: k

  defp ensure_atom(k) when is_binary(k) do
    # Use to_existing_atom to prevent atom exhaustion.
    # If the atom doesn't exist, we keep it as a string.
    # The compiler/resolvers should be updated to handle both atom and string keys.
    try do
      String.to_existing_atom(k)
    rescue
      ArgumentError -> k
    end
  end

  defp get_param(params, key_str) do
    # Try atom first, then string
    atom_key =
      try do
        String.to_existing_atom(key_str)
      rescue
        ArgumentError -> nil
      end

    if atom_key do
      Map.get(params, atom_key) || Map.get(params, key_str)
    else
      Map.get(params, key_str)
    end
  end

  def compile_string(content, params, opts \\ []) do
    compile(content, params, opts)
  end

  def invalidate_cache(prompt_name) do
    Structural.invalidate_name(prompt_name)
    Vary.invalidate_prompt(prompt_name)
    :ok
  end

  def invalidate_all_cache do
    Structural.clear()
    Fragment.clear()
    Vary.clear()
    :ok
  end

  def cache_stats do
    %{
      structural: Structural.count(),
      fragment: Fragment.count(),
      vary: Vary.count()
    }
  end

  # Extracts line number from error message and tokens
  # If the error message doesn't already include line info, try to find the relevant token
  defp extract_error_with_line(message, tokens) do
    # Check if message already has line info
    if String.contains?(message, "line") or String.contains?(message, "at line") do
      message
    else
      # Try to find the last token position to give a hint
      # This helps identify where the error occurred
      last_token = List.last(tokens)

      if last_token && last_token.line do
        "#{message} (near line #{last_token.line})"
      else
        message
      end
    end
  end

  # Extracts line number for validation errors by finding the variable in source
  defp add_line_info_to_validation_error(message, content) when is_binary(content) do
    # Check if message already has line info
    if String.contains?(message, "line") do
      message
    else
      # Try to extract the variable name from the error message
      # Patterns: "unknown_variable: @var referenced but not declared"
      #          "missing_param: @var required but not provided"
      case Regex.run(
             ~r/(unknown_variable|missing_param|invalid_type|invalid_enum|out_of_range):\s*@?(\w+)/,
             message
           ) do
        [_, _type, var_name] ->
          # Find the line number where this variable appears in the source
          case find_var_line_number(content, var_name) do
            nil -> message
            line_num -> "#{message} (at line #{line_num})"
          end

        _ ->
          message
      end
    end
  end

  defp find_var_line_number(content, var_name) do
    content
    |> String.split(["\r\n", "\n"], trim: false)
    |> Enum.with_index(1)
    |> Enum.reduce_while(nil, fn {line, line_num}, _acc ->
      # Look for @var_name pattern in the line
      if String.contains?(line, "@#{var_name}") do
        {:halt, line_num}
      else
        {:cont, nil}
      end
    end)
  end

  defp stale?(files_meta) when is_map(files_meta) do
    Enum.any?(files_meta, fn {path, cached_mtime} ->
      case File.stat(path) do
        {:ok, %{mtime: disk_mtime}} -> disk_mtime > cached_mtime
        _ -> true
      end
    end)
  end

  defp stale?(_), do: true

  @spec compile_ast(
          [any()],
          params(),
          map(),
          map(),
          MapSet.t(),
          integer(),
          map(),
          integer(),
          map()
        ) :: {iodata(), map(), MapSet.t(), map(), integer()} | {:error, map()}
  defp compile_ast(
         nodes,
         params,
         fragment_defs,
         vary_map,
         used_vars,
         indent_level,
         files_meta,
         section_count,
         declarations
       ) do
    indent = String.duplicate("  ", indent_level)

    Enum.reduce_while(nodes, {[], vary_map, used_vars, files_meta, section_count}, fn node, acc ->
      case node do
        {:text, t} ->
          handle_text_node(t, params, indent, acc)

        {:if, var, cond, then_nodes, elifs, else_node} ->
          handle_if_node(
            var,
            cond,
            then_nodes,
            elifs,
            else_node,
            params,
            declarations,
            indent_level,
            acc
          )

        {:case, var, branches} ->
          handle_case_node(var, branches, params, declarations, indent_level, acc)

        {:vary, name, branches} ->
          handle_vary_node(name, branches, params, fragment_defs, declarations, indent_level, acc)

        {:fragment_static, path} ->
          handle_static_fragment(path, fragment_defs, params, indent, acc)

        {:fragment_dynamic, path} ->
          handle_dynamic_fragment(path, acc)

        _ ->
          {:cont, acc}
      end
    end)
    |> wrap_result()
  end

  defp handle_text_node(
         text,
         params,
         indent,
         {acc_text, acc_vary, acc_vars, acc_files, acc_count}
       ) do
    vars_in_text = Regex.scan(~r/@(\w+)/, text, capture: :all_but_first) |> List.flatten()
    new_vars = Enum.reduce(vars_in_text, acc_vars, &MapSet.put(&2, &1))

    interpolated =
      Enum.reduce(params, text, fn {key, value}, inner_acc ->
        key_str = to_string(key)
        val_str = if is_list(value), do: Enum.join(value, ", "), else: to_string(value)
        String.replace(inner_acc, "@#{key_str}", val_str)
      end)

    indented_text =
      interpolated
      |> String.split("\n")
      |> Enum.map(fn line -> if line == "", do: "\n", else: [indent, line, "\n"] end)

    {:cont, {[acc_text, indented_text], acc_vary, new_vars, acc_files, acc_count}}
  end

  defp handle_if_node(
         var,
         cond,
         then_nodes,
         elifs,
         else_node,
         params,
         declarations,
         indent_level,
         {acc_text, acc_vary, acc_vars, acc_files, acc_count}
       ) do
    var_name_str = String.trim_leading(var, "@")
    var_value = get_param(params, var_name_str)
    current_vars = MapSet.put(acc_vars, var_name_str)

    {nodes_to_compile, val_label} =
      resolve_if_branch(var_value, cond, then_nodes, elifs, else_node)

    nodes_result =
      if nodes_to_compile do
        compile_ast(
          nodes_to_compile,
          params,
          %{},
          acc_vary,
          current_vars,
          indent_level + 1,
          acc_files,
          acc_count + 1,
          declarations
        )
      else
        {"", acc_vary, current_vars, acc_files, acc_count}
      end

    case nodes_result do
      {:error, _} = err ->
        {:halt, err}

      {inner_text, inner_vary, inner_vars, inner_files, inner_count} ->
        result_text =
          build_if_result(
            var_name_str,
            var,
            val_label,
            declarations,
            indent_level,
            acc_count,
            inner_text
          )

        {:cont, {[acc_text, result_text], inner_vary, inner_vars, inner_files, inner_count}}
    end
  end

  defp resolve_if_branch(var_value, cond, then_nodes, elifs, else_node) do
    cond do
      IfResolver.resolve(var_value, cond) && then_nodes != [] ->
        {then_nodes, "true"}

      true ->
        case Enum.find(elifs, fn {c, nodes} -> IfResolver.resolve(var_value, c) && nodes != [] end) do
          nil -> if else_node && else_node != [], do: {else_node, "false"}, else: {nil, nil}
          {c, ns} -> {ns, to_string(c)}
        end
    end
  end

  defp build_if_result(
         _var_name_str,
         _var,
         nil,
         _declarations,
         _indent_level,
         _acc_count,
         inner_text
       ),
       do: inner_text

  defp build_if_result(
         var_name_str,
         var,
         val_label,
         declarations,
         indent_level,
         acc_count,
         inner_text
       ) do
    options =
      case Map.get(declarations || %{}, var_name_str) do
        %{type: :enum, values: values} -> Enum.join(values, ",")
        _ -> "true,false"
      end

    [
      "\n[[section:branch:",
      to_string(indent_level),
      ":",
      to_string(acc_count),
      ":",
      var_name_str,
      ":",
      options,
      ":",
      var,
      " → ",
      val_label,
      "]]\n",
      inner_text,
      "\n\n[[/section]]\n"
    ]
  end

  defp handle_case_node(
         var,
         branches,
         params,
         declarations,
         indent_level,
         {acc_text, acc_vary, acc_vars, acc_files, acc_count}
       ) do
    var_name_str = String.trim_leading(var, "@")
    var_value = get_param(params, var_name_str)
    current_vars = MapSet.put(acc_vars, var_name_str)
    nodes_to_compile = CaseResolver.resolve(var_value, branches)
    match_label = find_case_match_label(branches, var_value)

    options =
      case Map.get(declarations || %{}, var_name_str) do
        %{values: vals} when is_list(vals) -> Enum.join(vals, ",")
        _ -> ""
      end

    result =
      if nodes_to_compile != [] do
        compile_ast(
          nodes_to_compile,
          params,
          %{},
          acc_vary,
          current_vars,
          indent_level + 1,
          acc_files,
          acc_count + 1,
          declarations
        )
      else
        {"", acc_vary, current_vars, acc_files, acc_count}
      end

    case result do
      {:error, _} = err ->
        {:halt, err}

      {inner_text, inner_vary, inner_vars, inner_files, inner_count} ->
        section_header = [
          "\n[[section:case:",
          to_string(indent_level),
          ":",
          to_string(acc_count),
          ":",
          var_name_str,
          ":",
          options,
          ":",
          var,
          " → ",
          to_string(match_label),
          "]]\n"
        ]

        {:cont,
         {[acc_text, section_header, inner_text, "[[/section]]\n"], inner_vary, inner_vars,
          inner_files, inner_count}}
    end
  end

  defp find_case_match_label(branches, var_value) do
    Enum.find_value(branches, fn
      branch when is_tuple(branch) and tuple_size(branch) == 3 ->
        {id, lbl, _ns} = branch

        if to_string(id) == to_string(var_value),
          do: String.trim_leading(lbl, "#") |> String.trim(),
          else: nil

      {:if, var_name, _, _, _, _} = _branch ->
        if to_string(var_name) == to_string(var_value), do: to_string(var_name), else: nil

      _ ->
        nil
    end) || to_string(var_value)
  end

  defp handle_vary_node(
         name,
         branches,
         params,
         fragment_defs,
         declarations,
         indent_level,
         {acc_text, acc_vary, acc_vars, acc_files, acc_count}
       ) do
    options = Enum.map_join(branches, ",", fn {k, _, _} -> to_string(k) end)
    placeholder = ["[[vary:\"", to_string(name), "\"]]"]

    result =
      Enum.reduce_while(branches, {[], acc_vary, acc_vars, acc_files, acc_count}, fn {id, label,
                                                                                      nodes},
                                                                                     {acc_b,
                                                                                      var_acc,
                                                                                      vars_acc,
                                                                                      files_acc,
                                                                                      count_acc} ->
        case compile_ast(
               nodes,
               params,
               fragment_defs,
               var_acc,
               vars_acc,
               0,
               files_acc,
               0,
               declarations
             ) do
          {:error, _} = err ->
            {:halt, err}

          {branch_text, branch_vary, branch_vars, branch_files, _} ->
            branch_str = IO.iodata_to_binary(branch_text)

            {:cont,
             {acc_b ++ [{id, label, branch_str}], branch_vary, branch_vars, branch_files,
              count_acc}}
        end
      end)

    case result do
      {:error, _} = err ->
        {:halt, err}

      {compiled_branches, inner_vary, inner_vars, inner_files, inner_count} ->
        new_vary = Map.put(inner_vary, name, compiled_branches)

        section_header = [
          "\n[[section:vary:",
          to_string(indent_level),
          ":",
          to_string(acc_count),
          ":",
          "_vary_#{name}",
          ":",
          options,
          ":",
          name,
          "]]\n"
        ]

        {:cont,
         {[acc_text, section_header, placeholder, "\n\n[[/section]]\n"], new_vary, inner_vars,
          inner_files, inner_count}}
    end
  end

  defp handle_static_fragment(
         path,
         fragment_defs,
         params,
         indent,
         {acc_text, acc_vary, acc_vars, acc_files, acc_count}
       ) do
    name = path |> String.trim_leading("{") |> String.trim_trailing("}")

    case Map.get(fragment_defs, name) do
      %{type: type} = spec ->
        from = spec[:from] || name

        expand_static_fragment(
          name,
          from,
          type,
          spec,
          params,
          indent,
          acc_text,
          acc_vary,
          acc_vars,
          acc_files,
          acc_count
        )

      _ ->
        expand_fragment_by_path(
          path,
          params,
          indent,
          acc_text,
          acc_vary,
          acc_vars,
          acc_files,
          acc_count
        )
    end
  end

  defp expand_static_fragment(
         name,
         from,
         type,
         spec,
         params,
         indent,
         acc_text,
         acc_vary,
         acc_vars,
         acc_files,
         acc_count
       ) do
    if String.ends_with?(from, "/") or !String.contains?(from, ".") do
      case FragmentCollection.expand(from, params, 0, acc_files, acc_count, spec) do
        {:ok, inner_text, child_files, child_count} ->
          {:cont, {[acc_text, inner_text], acc_vary, acc_vars, child_files, child_count}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    else
      fragment_result =
        if String.starts_with?(type, "static"),
          do: FragmentStatic.expand(from, params),
          else: FragmentDynamic.expand(from, params)

      case fragment_result do
        {:ok, content_result, child_files} ->
          indented_content = indent_content(content_result, indent)
          clean_name = String.replace_suffix(name, ".prompt", "")
          clean_from = String.replace_suffix(from, ".prompt", "")

          {:cont,
           {[
              acc_text,
              "\n[[section:frag:0:#{acc_count}:::fragment: ",
              clean_name,
              " → ",
              clean_from,
              "]]\n",
              indented_content,
              "\n[[/section]]\n"
            ], acc_vary, acc_vars, Map.merge(acc_files, child_files), acc_count + 1}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end
  end

  defp expand_fragment_by_path(
         path,
         params,
         indent,
         acc_text,
         acc_vary,
         acc_vars,
         acc_files,
         acc_count
       ) do
    if String.ends_with?(path, "/") or !String.contains?(path, ".") do
      case FragmentCollection.expand(path, params, 0, acc_files, acc_count) do
        {:ok, inner_text, child_files, child_count} ->
          {:cont, {[acc_text, inner_text], acc_vary, acc_vars, child_files, child_count}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    else
      case FragmentStatic.expand(path, params) do
        {:ok, content_result, child_files} ->
          indented_content = indent_content(content_result, indent)
          clean_path = String.replace_suffix(path, ".prompt", "")

          {:cont,
           {[
              acc_text,
              "\n[[section:frag:0:#{acc_count}:::fragment: ",
              clean_path,
              " → ",
              clean_path,
              "]]\n",
              indented_content,
              "\n[[/section]]\n"
            ], acc_vary, acc_vars, Map.merge(acc_files, child_files), acc_count + 1}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end
  end

  defp handle_dynamic_fragment(path, {acc_text, acc_vary, acc_vars, acc_files, acc_count}) do
    {:cont, {[acc_text, path], acc_vary, acc_vars, acc_files, acc_count}}
  end

  defp wrap_result({:error, _} = err), do: err
  defp wrap_result({text, v, vars, f, c}), do: {text, v, vars, f, c}

  def prompts_dir do
    # Prioritise env override (used in tests)
    case Application.get_env(:dot_prompt, :prompts_dir) do
      nil ->
        # Original complex lookup
        dir = "prompts"
        cwd = File.cwd!()

        cond do
          File.exists?(Path.join(cwd, dir)) ->
            Path.expand(Path.join(cwd, dir))

          File.exists?(Path.join([cwd, "dot_prompt", dir])) ->
            Path.expand(Path.join([cwd, "dot_prompt", dir]))

          File.exists?(Path.join([cwd, "..", "..", dir])) ->
            Path.expand(Path.join([cwd, "..", "..", dir]))

          true ->
            Path.expand(dir)
        end

      dir ->
        Path.expand(dir)
    end
  end

  defp load_prompt_file_with_meta(name, major) do
    prompts_dir = prompts_dir()
    name_str = to_string(name)
    {content, mtime, full_path} = resolve_prompt_path(prompts_dir, name_str)

    if major && content do
      check_major_version(
        name,
        major,
        content,
        {content, mtime, full_path},
        prompts_dir,
        name_str
      )
    else
      if is_nil(content),
        do: raise("prompt_not_found: #{name}"),
        else: {content, mtime, full_path}
    end
  end

  defp resolve_prompt_path(prompts_dir, name_str) do
    path = Path.join(prompts_dir, name_str)

    cond do
      File.exists?(path) and !File.dir?(path) ->
        {File.read!(path), File.stat!(path).mtime, path}

      File.exists?(path <> ".prompt") ->
        p = path <> ".prompt"
        {File.read!(p), File.stat!(p).mtime, p}

      File.dir?(path) and File.exists?(Path.join(path, "_index.prompt")) ->
        p = Path.join(path, "_index.prompt")
        {File.read!(p), File.stat!(p).mtime, p}

      true ->
        {nil, nil, nil}
    end
  end

  defp check_major_version(name, major, content, path_info, prompts_dir, name_str) do
    tokens = Lexer.tokenize(content)

    case Parser.parse(tokens) do
      {:ok, %{init: %{def: def_map}}} ->
        file_version = def_map[:version]
        file_major = major_from_version(file_version)

        if file_major == major do
          {content, mtime, full_path} = path_info
          {content, mtime, full_path}
        else
          find_archive_or_raise(name, major, prompts_dir, name_str)
        end

      _ ->
        if major == 1 do
          {content, mtime, full_path} = path_info
          {content, mtime, full_path}
        else
          raise "prompt_not_found: #{name} with major version #{major}"
        end
    end
  end

  defp find_archive_or_raise(name, major, prompts_dir, name_str) do
    name_parts = Path.split(name_str)

    archive_path =
      if length(name_parts) > 1 do
        dir = Path.dirname(name_str)
        base = Path.basename(name_str)
        Path.join([prompts_dir, dir, "archive", "#{base}_v#{major}.prompt"])
      else
        Path.join([prompts_dir, "archive", "#{name_str}_v#{major}.prompt"])
      end

    if File.exists?(archive_path) do
      {File.read!(archive_path), File.stat!(archive_path).mtime, archive_path}
    else
      raise "prompt_not_found: #{name} with major version #{major}"
    end
  end

  defp cache_key_for_compile(:inline, params, content, annotated) do
    compile_params =
      params
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.into(%{})

    params_hash = :erlang.phash2(compile_params)
    content_hash = :erlang.phash2(content)
    {"inline", params_hash, content_hash, annotated}
  end

  defp cache_key_for_compile(prompt_key, params, content, annotated) do
    compile_params =
      params
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.into(%{})

    # Content hash implicitly covers @version changes
    content_hash = :erlang.phash2(content)
    params_hash = :erlang.phash2(compile_params)
    {to_string(prompt_key), params_hash, content_hash, annotated}
  end

  defp count_tokens(text) do
    binary = if is_binary(text), do: text, else: IO.iodata_to_binary(text)
    words = binary |> String.trim() |> String.split()
    div(length(words) * 4, 3)
  end

  defp strip_annotations(text) do
    text
    |> String.replace(~r/\[\[section:[^\]]+\]\]\n?/, "")
    |> String.replace(~r/\n?\[\[\/section\]\]/, "")
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp major_from_version(nil), do: 1
  defp major_from_version(version) when is_integer(version), do: version

  defp major_from_version(version) when is_binary(version) do
    version = String.replace(version, "v", "")

    case Integer.parse(version) do
      {major, "." <> _} -> major
      {major, _} -> major
      _ -> 1
    end
  end

  defp indent_content(content, indent) when is_binary(content) do
    if indent == "" do
      content
    else
      content
      |> String.split("\n")
      |> Enum.map(fn
        "" -> ""
        "[[" <> _ = line -> line
        line -> [indent, line]
      end)
      |> Enum.intersperse("\n")
    end
  end

  defp indent_content(content, indent) do
    # If it's already iodata, we flatten it just enough to split by lines
    # or better: convert to binary once and then use the binary version.
    # For fragments, they are often cached as iodata but resolve-flat.
    indent_content(IO.iodata_to_binary(content), indent)
  end

  defp validate_params_if_needed(_params, declarations) when declarations == %{}, do: :ok

  defp validate_params_if_needed(params, declarations) do
    Validator.validate_params(params, declarations)
  end

  defp apply_defaults(params, declarations) do
    declarations
    |> Enum.filter(fn {_name, spec} -> Map.has_key?(spec, :default) and spec.default != nil end)
    |> Enum.reduce(params, fn {name, spec}, acc ->
      clean_name = name |> String.trim_leading("@")
      clean_atom = String.to_atom(clean_name)

      if Map.has_key?(acc, clean_atom) or Map.has_key?(acc, clean_name) do
        acc
      else
        Map.put(acc, clean_atom, spec.default)
      end
    end)
  end

  @doc """
  Validates an LLM response against a response contract.
  """
  @spec validate_output(String.t(), map(), keyword()) :: :ok | {:error, String.t()}
  def validate_output(response_json, contract, opts \\ []) do
    strict = Keyword.get(opts, :strict, true)

    case Jason.decode(response_json) do
      {:ok, response} when is_map(response) ->
        validate_response(response, contract, strict)

      {:ok, _} ->
        {:error, "Response must be a JSON object"}

      {:error, reason} ->
        {:error, "Invalid JSON: #{inspect(reason)}"}
    end
  end

  defp validate_response(response, contract, strict) do
    errors =
      for {field, field_spec} <- contract, reduce: [] do
        acc ->
          required = Map.get(field_spec, :required, false)
          expected_type = Map.get(field_spec, :type, "string")

          field_errors =
            with :ok <- check_required_field(required, field, response),
                 :ok <- check_field_type(field, expected_type, response) do
              []
            else
              {:error, msg} -> [msg]
            end

          acc ++ field_errors
      end

    final_errors =
      if strict and Map.keys(response) -- Map.keys(contract) != [] do
        extra_fields = Map.keys(response) -- Map.keys(contract)
        errors ++ ["Unexpected fields: #{Enum.join(extra_fields, ", ")}"]
      else
        errors
      end

    case final_errors do
      [] -> :ok
      errors -> {:error, Enum.join(errors, "; ")}
    end
  end

  defp check_required_field(true, field, response) do
    if Map.has_key?(response, field), do: :ok, else: {:error, "Missing required field: #{field}"}
  end

  defp check_required_field(false, _field, _response), do: :ok

  defp check_field_type(_field, _expected_type, response) when response == %{}, do: :ok

  defp check_field_type(field, expected_type, response) do
    if Map.has_key?(response, field) do
      actual_value = Map.get(response, field)
      actual_type = infer_type(actual_value)

      if type_matches?(expected_type, actual_type) do
        :ok
      else
        {:error, "Field #{field} has type #{actual_type}, expected #{expected_type}"}
      end
    else
      :ok
    end
  end

  defp infer_type(v) when is_binary(v), do: "string"
  defp infer_type(v) when is_integer(v), do: "number"
  defp infer_type(v) when is_float(v), do: "number"
  defp infer_type(v) when is_boolean(v), do: "boolean"
  defp infer_type(v) when is_nil(v), do: "null"
  defp infer_type(v) when is_list(v), do: "array"
  defp infer_type(v) when is_map(v), do: "object"
  defp infer_type(_), do: "unknown"

  defp type_matches?("string", "string"), do: true
  defp type_matches?("string", "null"), do: true
  defp type_matches?("number", "number"), do: true
  defp type_matches?("boolean", "boolean"), do: true
  defp type_matches?("null", "null"), do: true
  defp type_matches?("array", "array"), do: true
  defp type_matches?("object", "object"), do: true
  defp type_matches?(_, _), do: false
end
