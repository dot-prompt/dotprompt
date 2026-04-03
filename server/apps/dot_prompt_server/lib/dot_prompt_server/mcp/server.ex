defmodule DotPromptServer.MCP.Server do
  @moduledoc """
  MCP Server for dot-prompt.
  Reads JSON-RPC from stdin, writes to stdout.
  """

  def start do
    stream = IO.stream(:stdio, :line)
    Enum.each(stream, &handle_line/1)
  end

  defp handle_line(line) do
    case Jason.decode(line) do
      {:ok, %{"jsonrpc" => "2.0"} = request} ->
        response = process_request(request)
        IO.puts(Jason.encode!(response))

      _ ->
        :ok
    end
  end

  def process_request(%{"method" => "prompt_list", "id" => id}) do
    %{jsonrpc: "2.0", id: id, result: %{prompts: DotPrompt.list_prompts()}}
  end

  def process_request(%{"method" => "collection_list", "id" => id}) do
    %{jsonrpc: "2.0", id: id, result: %{collections: DotPrompt.list_collections()}}
  end

  def process_request(%{
        "method" => "prompt_schema",
        "params" => %{"name" => name} = params,
        "id" => id
      }) do
    major =
      case params["major"] do
        nil ->
          nil

        val when is_binary(val) ->
          case Integer.parse(val) do
            {n, ""} -> n
            _ -> nil
          end

        val when is_integer(val) ->
          val
      end

    case DotPrompt.schema(name, major) do
      {:ok, schema} ->
        %{jsonrpc: "2.0", id: id, result: schema}

      {:error, details} ->
        error_msg =
          if is_map(details) and Map.has_key?(details, :error),
            do: details.error,
            else: "unknown_error"

        # For schema errors (non-existent prompt), we return the error in result rather than as json-rpc error
        # This matches MCP protocol for resource not found
        %{jsonrpc: "2.0", id: id, result: %{error: error_msg}}
    end
  end

  def process_request(%{
        "method" => "collection_schema",
        "params" => %{"name" => name} = params,
        "id" => id
      }) do
    major =
      case params["major"] do
        nil ->
          nil

        val when is_binary(val) ->
          case Integer.parse(val) do
            {n, ""} -> n
            _ -> nil
          end

        val when is_integer(val) ->
          val
      end

    case DotPrompt.schema(name, major) do
      {:ok, schema} ->
        %{jsonrpc: "2.0", id: id, result: schema}

      {:error, details} ->
        error_msg =
          if is_map(details) and Map.has_key?(details, :error),
            do: details.error,
            else: "unknown_error"

        %{jsonrpc: "2.0", id: id, result: %{error: error_msg}}
    end
  end

  def process_request(%{
        "method" => "prompt_compile",
        "params" => %{"name" => name, "params" => params} = params_map,
        "id" => id
      }) do
    opts =
      []
      |> maybe_put(:seed, params_map["seed"])
      |> maybe_put(:major, params_map["major"])

    case DotPrompt.compile(name, params, opts) do
      {:ok, %DotPrompt.Result{} = result} ->
        %{
          jsonrpc: "2.0",
          id: id,
          result: %{
            template: result.prompt,
            vary_selections: result.vary_selections,
            response_contract: result.response_contract,
            warnings: result.metadata.warnings
          }
        }

      {:error, details} ->
        %{
          jsonrpc: "2.0",
          id: id,
          error: %{code: -32_000, message: details.message, data: details}
        }
    end
  end

  def process_request(%{"id" => id}) do
    %{jsonrpc: "2.0", id: id, error: %{code: -32_601, message: "Method not found"}}
  end

  def process_request(%{} = request) do
    id = Map.get(request, "id")
    %{jsonrpc: "2.0", id: id, error: %{code: -32_601, message: "Method not found"}}
  end

  defp maybe_put(list, _key, nil), do: list
  defp maybe_put(list, key, value), do: [{key, value} | list]
end
