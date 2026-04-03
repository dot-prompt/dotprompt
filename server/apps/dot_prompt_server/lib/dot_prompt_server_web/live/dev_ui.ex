defmodule DotPromptServerWeb.DevUI do
  @moduledoc """
  LiveView for the dot-prompt development UI.
  """
  use DotPromptServerWeb, :live_view
  import Phoenix.HTML
  require Logger

  on_mount({__MODULE__, :auto_compile})

  def on_mount(:auto_compile, _params, _session, socket) do
    send(self(), :auto_compile)
    {:cont, socket}
  end

  def mount(%{"file" => file_name}, _session, socket) do
    file_name =
      if is_list(file_name) do
        Enum.join(file_name, "/")
      else
        file_name
      end

    content = load_prompt_file(file_name)

    {active_schema, compile_params} =
      case DotPrompt.schema(file_name) do
        {:ok, schema} ->
          default_params =
            schema.params
            |> Enum.reject(fn {_, spec} -> spec.lifecycle == :runtime end)
            |> Enum.into(%{}, fn {k, spec} ->
              default =
                case spec.type do
                  :enum ->
                    values = Map.get(spec, :values, [])
                    if values != [] and values != nil, do: List.first(values), else: ""

                  :list_enum ->
                    values = Map.get(spec, :values, [])
                    if values != [] and values != nil, do: [List.first(values)], else: []

                  type when type in [:list, :list_str, :list_int] ->
                    values = Map.get(spec, :values, [])
                    if values != [] and values != nil, do: [List.first(values)], else: []

                  :int ->
                    case Map.get(spec, :range) do
                      [min, _max] -> min
                      _ -> 0
                    end

                  :bool ->
                    true

                  _ ->
                    Map.get(spec, :default, "")
                end

              {to_string(k), default}
            end)

          {schema, default_params}

        _ ->
          {nil, %{}}
      end

    {:ok,
     socket
     |> assign(
       prompts: DotPrompt.list_root_prompts(),
       fragments: DotPrompt.list_fragment_prompts(),
       fragment_tree: build_tree(DotPrompt.list_fragment_prompts()),
       collections: DotPrompt.list_collections(),
       active_tool: :editor,
       active_file: file_name,
       view_mode: :compiled,
       compile_params: compile_params,
       runtime_params: %{},
       source_content: content,
       compiled_content: nil,
       compiled_annotations: [],
       used_vars: MapSet.new(),
       scratch_edits: nil,
       section_popover: nil,
       vary_selections: %{},
       seed: 1,
       is_compiling: false,
       cache_hit: nil,
       token_count: nil,
       min_tokens: nil,
       max_tokens: nil,
       vary_slots: 0,
       show_params_pane: true,
       token_breakdown_open: false,
       runtime_popover: nil,
       runtime_fixtures: %{},
       commit_expanded: false,
       commit_version_type: :patch,
       error: nil,
       branch_annotations_collapsed: MapSet.new(),
       editing_line: nil,
       telemetry_events: [],
       active_schema: active_schema,
       nav_width: 180,
       params_width: 214,
       active_param_dropdown: nil,
       collapsed_folders: MapSet.new()
     )}
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       prompts: DotPrompt.list_root_prompts(),
       fragments: DotPrompt.list_fragment_prompts(),
       fragment_tree: build_tree(DotPrompt.list_fragment_prompts()),
       collections: DotPrompt.list_collections(),
       active_tool: :editor,
       active_file: nil,
       view_mode: :source,
       compile_params: %{},
       runtime_params: %{},
       source_content: "",
       compiled_content: nil,
       compiled_annotations: [],
       scratch_edits: nil,
       is_compiling: false,
       cache_hit: nil,
       token_count: nil,
       min_tokens: nil,
       max_tokens: nil,
       vary_slots: 0,
       show_params_pane: false,
       token_breakdown_open: false,
       runtime_popover: nil,
       runtime_fixtures: DotPromptServer.RuntimeStorage.get_all_fixtures(),
       commit_expanded: false,
       commit_version_type: :patch,
       error: nil,
       branch_annotations_collapsed: MapSet.new(),
       used_vars: MapSet.new(),
       seed: 1,
       editing_line: nil,
       telemetry_events: [],
       active_schema: nil,
       nav_width: 180,
       params_width: 214,
       active_param_dropdown: nil,
       collapsed_folders: MapSet.new()
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="shell">
      <.sidebar 
        prompts={@prompts}
        fragments={@fragments}
        collections={@collections}
        active_file={@active_file}
        active_tool={@active_tool}
        scratch_edits={@scratch_edits}
        nav_width={@nav_width}
        collapsed_folders={@collapsed_folders}
        fragment_tree={@fragment_tree}
      />

      <div id="nav-resizer" phx-hook="Resizable" data-target-id="nav-sidebar" data-side="left" class="resizer border-r border-gray-800"></div>
      
      <div class="main">
        <.toolbar 
          active_file={@active_file}
          view_mode={@view_mode}
          show_params_pane={@show_params_pane}
          token_breakdown_open={@token_breakdown_open}
          edit_mode={@scratch_edits != nil}
        />
        
        <%= if @error do %>
          <div class="error-banner">
            <div class="error-icon">!</div>
            <div class="error-content">
              <p class="error-type">Error</p>
              <p class="error-message"><%= @error %></p>
            </div>
          </div>
        <% end %>

        <div class="work" id="work">
          <div class="epane">
            <.scratch_banner 
              show={@scratch_edits != nil && @view_mode == :compiled && !@commit_expanded}
            />
            
            <.commit_row 
              show={@commit_expanded}
              version_type={@commit_version_type}
            />

            <div class="cscroll">
              <div class={"ced #{if @scratch_edits, do: "edit-mode", else: ""}"} id="ced">
                <%= case @active_tool do %>
                  <% :editor -> %>
                    <%= if @view_mode == :source do %>
                      <.source_editor content={@source_content} active_file={@active_file} editing_line={@editing_line} />
                    <% else %>
                      <%= if @compiled_content do %>
                        <%= highlight_compiled_content(@compiled_content, @compile_params, @branch_annotations_collapsed, @vary_selections, @section_popover) %>
                      <% else %>
                        <div class="cl">
                          <span class="ln">1</span>
                          <span class="cc"><span class="cm"># Select a file and switch to Compiled view</span></span>
                        </div>
                      <% end %>
                    <% end %>
                  
                  <% :render -> %>
                    <.render_test 
                      active_file={@active_file} 
                      compile_params={@compile_params}
                      runtime_params={@runtime_params}
                    />

                  <% :telemetry -> %>
                    <.telemetry_view />

                  <% :cache -> %>
                    <.cache_view />
                <% end %>
              </div>
            </div>

            <.status_bar 
              token_count={@token_count}
              min_tokens={@min_tokens}
              max_tokens={@max_tokens}
              cache_hit={@cache_hit}
              vary_slots={@vary_slots}
            />
          </div>

          <div id="params-resizer" phx-hook="Resizable" data-target-id="ppane" data-side="right" class={"resizer border-l border-gray-800 #{if !@show_params_pane, do: "hidden", else: ""}"}></div>

          <.params_pane
            show={@show_params_pane}
            compile_params={@compile_params}
            runtime_params={@runtime_params}
            runtime_popover={@runtime_popover}
            runtime_fixtures={@runtime_fixtures}
            used_vars={@used_vars}
            active_schema={@active_schema}
            is_compiling={@is_compiling}
            params_width={@params_width}
            active_param_dropdown={@active_param_dropdown}
            seed={@seed}
          />

          <.token_panel 
            show={@token_breakdown_open}
            token_count={@token_count}
            min_tokens={@min_tokens}
            max_tokens={@max_tokens}
            vary_slots={@vary_slots}
          />
        </div>
      </div>
    </div>
    """
  end

  # Sidebar component
  defp sidebar(assigns) do
    ~H"""
    <div class="nav" id="nav-sidebar" style={"width: #{@nav_width}px;"}>
      <div class="nav-head">
        <span class="logo"><em>.</em>prompt</span>
        <span class="epill">dev</span>
      </div>
      <div class="ns">
        <div class="nl">Prompts</div>
        <div class="fdir" phx-click="toggle_folder" phx-value-folder="prompts">
          <%= if MapSet.member?(@collapsed_folders, "prompts"), do: "▶", else: "▼" %> prompts
        </div>
        <%= if !MapSet.member?(@collapsed_folders, "prompts") do %>
          <%= for prompt <- @prompts do %>
            <.link patch={"/prompts/#{prompt}"} class={["fr", if(prompt == @active_file, do: "on")]}>
              <div class="fdot"></div><%= prompt %>
              <%= if @scratch_edits && Map.has_key?(@scratch_edits, prompt) do %>
                <div class="famd"></div>
              <% end %>
            </.link>
          <% end %>
        <% end %>
      </div>

      <div class="ns" style="margin-top: 8px">
        <div class="nl">Fragments</div>
        <.render_tree 
          tree={@fragment_tree} 
          active_file={@active_file} 
          collapsed_folders={@collapsed_folders} 
          parent_path="" 
        />
      </div>
      <div class="ndiv"></div>
      <div class="ns">
        <div class="nl">Tools</div>
        <% tools = [
          {:editor, "Editor", "/", "<rect x='1' y='1' width='11' height='11' rx='2' stroke='currentColor' stroke-width='1.1'/><path d='M4 5l2 2-2 2M7.5 9h2' stroke='currentColor' stroke-width='1.1' stroke-linecap='round'/>"},
          {:render, "Render test", "/render", "<path d='M2 4h9M2 6.5h6M2 9h4' stroke='currentColor' stroke-width='1.1' stroke-linecap='round'/>"},
          {:cache, "Cache / stats", "/cache", "<circle cx='6.5' cy='6.5' r='5' stroke='currentColor' stroke-width='1.1'/><path d='M6.5 4v2.5l1.5 1.5' stroke='currentColor' stroke-width='1.1' stroke-linecap='round'/>"},
          {:telemetry, "Telemetry", "/telemetry", "<path d='M1 9.5L4 6l2.5 2.5 5-6' stroke='currentColor' stroke-width='1.1' stroke-linecap='round' stroke-linejoin='round'/>"}
        ] %>
        <%= for {id, label, path, svg} <- tools do %>
          <.link 
            patch={path}
            class={"ni #{if @active_tool == id, do: "on", else: ""}"}
          >
            <svg viewBox="0 0 13 13" fill="none"><%= raw(svg) %></svg><%= label %>
          </.link>
        <% end %>
      </div>
      <div class="nbot">
        <button class="ni" style="font-size:11px">
          <svg viewBox="0 0 13 13" fill="none"><circle cx="6.5" cy="4" r="2" stroke="currentColor" stroke-width="1.1"/><path d="M2 11c0-2.2 2-4 4.5-4s4.5 1.8 4.5 4" stroke="currentColor" stroke-width="1.1" stroke-linecap="round"/></svg>Docs
        </button>
      </div>
    </div>
    """
  end

  # Toolbar component
  defp toolbar(assigns) do
    ~H"""
    <div class="tbar">
      <div class="vtog">
        <button 
          phx-click="set_view" 
          phx-value-view="source" 
          class={"vb #{if @view_mode == :source, do: "on", else: ""}"}
        >Source</button>
        <button 
          phx-click="set_view" 
          phx-value-view="compiled" 
          class={"vb #{if @view_mode == :compiled, do: "on", else: ""}"}
        >Compiled</button>
      </div>
      
      <%= if @active_file do %>
        <span class="tfile"><%= Path.basename(@active_file) %></span>
        <span class="tver">v<%= if assigns[:active_schema], do: @active_schema[:version] || 1, else: 1 %></span>
      <% end %>
      
      <div class="tright">
        <%= if @view_mode == :compiled && @active_file do %>
          <button 
            phx-click="toggle_edit" 
            class={"btn #{if @edit_mode, do: "btn-edit", else: ""}"}
          >
            <%= if @edit_mode, do: "Editing", else: "Edit" %>
          </button>
        <% end %>
        <button 
          phx-click="toggle_params" 
          class={"btn #{if @show_params_pane, do: "on", else: ""}"}
        >
          Params <%= if @show_params_pane, do: "‹", else: "›" %>
        </button>
        <button 
          phx-click="toggle_token_breakdown" 
          class={"btn #{if @token_breakdown_open, do: "on", else: ""}"}
        >
          Tokens <%= if @token_breakdown_open, do: "‹", else: "›" %>
        </button>
      </div>
    </div>
    """
  end

  # Scratch banner component
  defp scratch_banner(assigns) do
    ~H"""
    <div :if={@show} class="sbanner show">
      <div class="sdot"></div>
      <span class="slabel">Compiled scratchpad — local edits — <em>source unchanged.</em></span>
      <div class="sacts">
        <button phx-click="discard_scratch" class="btn">Discard</button>
        <button phx-click="expand_commit" class="btn btn-am">Commit…</button>
      </div>
    </div>
    """
  end

  # Commit row component
  defp commit_row(assigns) do
    ~H"""
    <div :if={@show} class="crow show">
      <span class="clbl">Bump version:</span>
      <div class="vops">
        <%= for type <- [:patch, :minor, :major] do %>
          <button 
            phx-click="select_commit_type" 
            phx-value-type={type} 
            class={"vbtn #{if @version_type == type, do: "on", else: ""}"}
          ><%= type %></button>
        <% end %>
      </div>
      <span class="vprev">v<%= (assigns[:active_schema] && assigns[:active_schema][:version]) || 1 %> → <span><%= preview_version((assigns[:active_schema] && assigns[:active_schema][:version]) || 1, @version_type) %></span></span>
      <div style="margin-left:auto;display:flex;gap:6px">
        <button class="btn" phx-click="cancel_commit">Cancel</button>
        <button class="btn btn-gr" phx-click="save_version">Save as new version</button>
      </div>
    </div>
    """
  end

  defp source_editor(assigns) do
    ~H"""
    <%= if @active_file do %>
      <div phx-window-keydown="handle_keydown" style="padding-top: 12px;">
        <%= for {line, i} <- Enum.with_index(String.split(@content, "\n"), 1) do %>
          <div 
            class={"cl #{if @editing_line == i, do: "hl-gr", else: ""} #{if String.trim(line) == "", do: "cl-empty", else: ""}"} 
            id={"source-line-#{i}"}
            phx-hook="SectionEdit"
            phx-click="focus_line"
            phx-keydown="handle_keydown"
            phx-value-index={i}
            data-index={i}
            tabindex="0"
          >
            <span class="ln"><%= i %></span>
            <%= if @editing_line == i do %>
              <form phx-change="update_line" phx-submit="save_line" class="edit-form">
                <input type="hidden" name="index" value={i} />
                <input 
                  type="text" 
                  name="value" 
                  class="edit-input"
                  value={line}
                  phx-blur="save_line"
                  phx-value-index={i}
                  phx-keydown="handle_edit_keydown"
                  autocomplete="off"
                />
              </form>
            <% else %>
              <span class="cc">
                <%= raw(highlight_source(line)) %>
              </span>
            <% end %>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="cl">
        <span class="ln">1</span>
        <span class="cc"><span class="cm"># Select a prompt file to begin</span></span>
      </div>
    <% end %>
    """
  end

  # Status bar component
  defp status_bar(assigns) do
    ~H"""
    <div class="sbar">
      <div class="st"><span class="slb">tokens</span><span class="sv sv-gr"><%= @token_count || 0 %></span></div>
      <div class="st"><span class="slb">min</span><span class="sv sv-mu"><%= @min_tokens || 0 %></span></div>
      <div class="st"><span class="slb">max</span><span class="sv sv-mu"><%= @max_tokens || 0 %></span></div>
      <div class="st"><span class="slb">cache</span><span class={"sv #{if @cache_hit, do: "sv-gr", else: "sv-am"}"}><%= if @cache_hit, do: "hit", else: "miss" %></span></div>
      <div class="st"><span class="slb">vary</span><span class="sv sv-pu"><%= @vary_slots %></span></div>
      <div class="sright">
        <div style="display:flex;align-items:center;gap:5px">
          <div class="sconndot"></div>
          <span class="slb" style="color:var(--mu)">:4040</span>
        </div>
      </div>
    </div>
    """
  end

  # Params pane component
  defp params_pane(assigns) do
    ~H"""
    <div class={"ppane #{if !@show, do: "closed", else: ""}"} id="ppane" style={"width: #{if @show, do: "#{@params_width}px", else: "0"};"}>
      <div class="ph">
        <span class="ptitle">Params</span>
        <button class="btn" style="margin-left:auto;padding:3px 7px;font-size:10px" phx-click="toggle_params">‹</button>
      </div>
      <div class="pbody">
        <div class="pgl">Compile-time</div>
        
        <%= if @active_schema do %>
          <form phx-change="update_compile_param_form">
            
            <% 
              compile_params = 
                @active_schema.params 
                |> Enum.filter(fn {n, s} -> s.lifecycle == :compile && n != "version" end)
                |> Enum.sort_by(fn {_, s} -> param_sort_weight(s.type) end)
            %>

            <%= for {name, spec} <- compile_params do %>
              <% is_used = MapSet.member?(@used_vars, to_string(name)) %>
              <div class={"pr #{if !is_used, do: "opacity-40 transition-opacity"}"}>
                <div class="plbl">
                  <span class="pn" title={"@#{name}"}>@<%= name %></span>
                  <span class="pt"><%= spec.type %></span>
                </div>                
                
                <%= if spec.type == :enum do %>
                  <select class="pi" name={name}>
                    <option value="">Select...</option>
                    <%= for v <- spec.values || [] do %>
                      <option value={v} selected={Map.get(@compile_params, name) == v}><%= v %></option>
                    <% end %>
                  </select>
                <% end %>

                <%= if spec.type in [:list, :list_enum, :list_str, :list_int] do %>
                  <%= if spec[:values] do %>
                    <div class="relative w-full">
                      <button 
                        type="button" 
                        class="pi w-full text-left flex justify-between items-center" 
                        phx-click="toggle_param_dropdown" 
                        phx-value-param={name}
                      >
                        <% 
                          selected = List.wrap(Map.get(@compile_params, name)) 
                          label = if selected == [], do: "Select...", else: "#{length(selected)} selected"
                        %>
                        <span class="truncate"><%= label %></span>
                        <span class="text-[9px] opacity-50">▼</span>
                      </button>
                      
                      <%= if @active_param_dropdown == to_string(name) do %>
                        <div class="popover dropdown-popover show" style="max-height: 200px; overflow-y: auto; width: 100%; left: 0; right: 0;">
                          <div class="pop-head">Select <%= name %><span class="pop-close" phx-click="close_param_dropdown">×</span></div>
                          <div class="p-2 flex flex-col gap-1">
                            <%= for v <- spec.values || [] do %>
                              <% is_selected = to_string(v) in Enum.map(selected, &to_string/1) %>
                              <label class="flex items-center gap-2 px-2 py-1.5 hover:bg-white/5 rounded cursor-pointer transition-colors">
                                <input 
                                  type="checkbox" 
                                  name={"#{name}[]"} 
                                  value={v} 
                                  checked={is_selected}
                                  class="w-3.5 h-3.5 rounded border-white/20 bg-transparent text-teal-600 focus:ring-0 focus:ring-offset-0"
                                >
                                <span class="text-xs text-[#dde1e8]"><%= v %></span>
                              </label>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% else %>
                    <input type="text" class="pi" 
                      name={name}
                      placeholder="values..."
                      value={format_param_value(Map.get(@compile_params, name))}>
                  <% end %>
                <% end %>

                <%= if spec.type == :bool do %>
                  <div class="flex items-center">
                    <label class="flex items-center gap-2 cursor-pointer w-full p-1.5 bg-white/5 rounded hover:bg-white/10 transition-colors">
                      <input 
                        type="checkbox" 
                        name={name} 
                        value="true"
                        checked={Map.get(@compile_params, name) == true}
                        class="w-4 h-4 rounded border-white/20 bg-transparent text-teal-600 focus:ring-0"
                      >
                      <span class="text-xs text-[#dde1e8]">Enabled</span>
                    </label>
                  </div>
                <% end %>

                <%= if spec.type == :int do %>
                  <% 
                    range = spec[:range] || [0, 100]
                    min_val = Enum.at(range, 0, 0)
                    max_val = Enum.at(range, 1, 100)
                    current_val = Map.get(@compile_params, name, min_val) 
                  %>
                  <div class="flex items-center gap-2 p-1.5 bg-white/5 rounded">
                    <input 
                      type="range" 
                      class="flex-1 h-1 bg-[#30363d] rounded-lg appearance-none cursor-pointer"
                      name={name}
                      min={min_val}
                      max={max_val}
                      value={current_val}
                    >
                    <span class="text-[10px] text-[#dde1e8] font-mono w-6 text-right"><%= current_val %></span>
                  </div>
                <% end %>

                <%= if spec.type not in [:enum, :list, :list_enum, :list_str, :list_int, :bool, :int] do %>
                  <input type="text" class="pi" 
                    name={name}
                    value={format_param_value(Map.get(@compile_params, name))}>
                <% end %>
              </div>
            <% end %>

            <button 
              type="button"
              class="btn btn-gr w-full" 
              style="margin-top:10px" 
              disabled={@is_compiling}
            >
              <%= if @is_compiling, do: "Compiling...", else: "Auto-compiled" %>
            </button>
          </form>

          <div class="pdiv"></div>
          <div class="pgl">Runtime</div>

          <% runtime_params = Enum.filter(@active_schema.params, fn {n, s} -> s.lifecycle == :runtime && n != "version" end) %>

          <%= for {name, spec} <- runtime_params do %>
            <div class="pr">
              <div class="plbl">
                <span class="pn" title={"@#{name}"}>@<%= name %></span>
                <span class="pt"><%= spec.type %></span>
              </div>
              <input
                class="pi rt"
                readonly
                value={format_param_value(Map.get(@runtime_params, to_string(name))) || "Enter #{name}..."}
                phx-click="open_runtime_popover"
                phx-value-param={name}
              >

              <%= if @runtime_popover == to_string(name) do %>
                <div class="popover-backdrop show" phx-click="close_runtime_popover"></div>
                <.runtime_popover
                  param={name}
                  value={format_param_value(Map.get(@runtime_params, to_string(name), ""))}
                  fixtures={Map.get(@runtime_fixtures, to_string(name), [])}
                />
              <% end %>
            </div>
          <% end %>
        <% else %>
          <div class="p-4 text-center text-xs text-[#6e7681] italic">
            Select a prompt to see params
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp runtime_popover(assigns) do
    ~H"""
    <div class="popover show">
      <div class="pop-head">@<%= @param %><span class="pop-close" phx-click="close_runtime_popover">×</span></div>
      <form phx-change="update_runtime_param" phx-submit="close_runtime_popover">
        <input name="value" class="pop-input" value={@value} autofocus>
        <input type="hidden" name="name" value={@param}>
      </form>
      <div class="pop-flbl">Saved fixtures</div>
      <%= for {label, val} <- @fixtures do %>
        <div class="pf-row" phx-click="load_fixture" phx-value-param={@param} phx-value-value={val}>
          <span class="pf-lbl text-left"><%= label %></span><span class="pf-val"><%= val %></span>
          <span class="pf-del" phx-click="delete_fixture" phx-value-param={@param} phx-value-label={label} phx-capture-click>×</span>
        </div>
      <% end %>
      <button class="pop-save" phx-click="save_fixture" phx-value-param={@param}>Save current as fixture…</button>
    </div>
    """
  end

  defp render_test(assigns) do
    ~H"""
    <div class="p-6">
      <h3 class="text-lg font-bold mb-4 text-[#14b8a6]">Full Render Test</h3>
      <div class="bg-[#0d1117] border border-[#30363d] rounded-lg p-4">
        <div class="flex justify-between items-center mb-4">
          <span class="text-xs text-[#6e7681]">Final output with injected runtime variables</span>
          <button phx-click="full_render" class="btn btn-gr">Run Render</button>
        </div>
        <div class="bg-[#08090b] rounded p-4 min-h-[200px] font-mono text-sm whitespace-pre-wrap border border-[#30363d]">
          <%= if @active_file do %>
            <div id="render-output">
              # Click 'Run Render' to see final output
            </div>
          <% else %>
            <span class="text-[#6e7681]"># Select a file to test rendering</span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp telemetry_view(assigns) do
    events = DotPrompt.Telemetry.list_events()
    assigns = assign(assigns, telemetry_events: events)

    ~H"""
    <div class="p-6">
      <h3 class="text-lg font-bold mb-4 text-[#8b84e8]">Telemetry Events</h3>
      <div class="space-y-2">
        <div class="flex text-xs font-bold text-[#6e7681] px-2 uppercase mb-2">
          <span class="w-1/3">Prompt / Time</span>
          <span class="w-1/6 text-right">Duration</span>
          <span class="w-1/6 text-right">Tokens</span>
          <span class="w-1/6 text-center">Cache</span>
        </div>
        <div class="bg-[#0d1117] border border-[#30363d] rounded-lg divide-y divide-[#30363d] overflow-hidden">
          <%= if @telemetry_events == [] do %>
            <div class="p-8 text-center text-[#6e7681] text-sm italic">
              No recent events. Execute renders to see telemetry.
            </div>
          <% else %>
            <%= for entry <- @telemetry_events do %>
              <div class="flex items-center p-3 text-sm hover:bg-[#1a1e26]">
                <div class="w-1/3">
                  <div class="font-bold text-[#dde1e8]"><%= entry.metadata.prompt %></div>
                  <div class="text-[10px] text-[#52586a]"><%= Calendar.strftime(entry.time, "%H:%M:%S") %></div>
                </div>
                <div class="w-1/6 text-right font-mono text-[#14b8a6]">
                  <%= entry.measurements.duration %>ms
                </div>
                <div class="w-1/6 text-right font-mono text-[#4a9edd]">
                  <%= Map.get(entry.measurements, :compiled_tokens, 0) %>
                </div>
                <div class="w-1/6 text-center">
                  <%= if Map.get(entry.measurements, :cache_hit) do %>
                    <span class="px-1.5 py-0.5 rounded text-[10px] bg-[#1d9e75]/20 text-[#1d9e75] border border-[#1d9e75]/30">HIT</span>
                  <% else %>
                    <span class="px-1.5 py-0.5 rounded text-[10px] bg-[#e05555]/10 text-[#52586a] border border-[#52586a]/30">MISS</span>
                  <% end %>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp cache_view(assigns) do
    stats = DotPrompt.cache_stats()
    assigns = assign(assigns, stats: stats)

    ~H"""
    <div class="p-6">
      <h3 class="text-lg font-bold mb-4 text-[#ef9f27]">Cache Statistics</h3>
      <div class="grid grid-cols-3 gap-4">
        <div class="bg-[#0d1117] border border-[#30363d] rounded-lg p-4">
          <div class="text-xs text-[#6e7681] uppercase mb-1">Structural</div>
          <div class="text-2xl font-bold text-[#14b8a6]"><%= @stats.structural %> <span class="text-sm font-normal text-[#6e7681]">entries</span></div>
        </div>
        <div class="bg-[#0d1117] border border-[#30363d] rounded-lg p-4">
          <div class="text-xs text-[#6e7681] uppercase mb-1">Fragment</div>
          <div class="text-2xl font-bold text-[#4a9edd]"><%= @stats.fragment %> <span class="text-sm font-normal text-[#6e7681]">entries</span></div>
        </div>
        <div class="bg-[#0d1117] border border-[#30363d] rounded-lg p-4">
          <div class="text-xs text-[#6e7681] uppercase mb-1">Vary</div>
          <div class="text-2xl font-bold text-[#8b84e8]"><%= @stats.vary %> <span class="text-sm font-normal text-[#6e7681]">entries</span></div>
        </div>
      </div>
      <div class="mt-6 flex gap-4">
        <button phx-click="clear_cache" class="btn btn-am">Clear All Caches</button>
      </div>
    </div>
    """
  end

  defp token_panel(assigns) do
    ~H"""
    <div class={"tok-panel #{if @show, do: "open", else: ""}"}>
      <div class="tp-head">
        <span class="tp-title">Tokens</span>
        <span class="tp-close" phx-click="toggle_token_breakdown">‹</span>
      </div>
      <div class="tp-body">
        <div class="tp-cards">
          <div class="tp-card"><div class="tp-cl">Compiled</div><div class="tp-cv sv-gr"><%= @token_count || 0 %></div></div>
          <div class="tp-card"><div class="tp-cl">After inject</div><div class="tp-cv sv-am"><%= (@token_count || 0) + 75 %></div></div>
          <div class="tp-card"><div class="tp-cl">Min</div><div class="tp-cv sv-mu"><%= @min_tokens || 0 %></div></div>
          <div class="tp-card"><div class="tp-cl">Max</div><div class="tp-cv sv-mu"><%= @max_tokens || 0 %></div></div>
        </div>
        <div class="tp-sec">
          <div class="tp-sl">Composition</div>
          <div class="tp-track">
            <div class="tp-seg" style="width:38%;background:var(--gr);opacity:0.75"></div>
            <div class="tp-seg" style="width:31%;background:var(--bl);opacity:0.75"></div>
            <div class="tp-seg" style="width:18%;background:var(--pu);opacity:0.75"></div>
            <div class="tp-seg" style="width:13%;background:var(--am);opacity:0.7"></div>
          </div>
          <div class="tp-legend">
            <div class="tp-leg"><div class="tp-legdot" style="background:var(--gr);opacity:0.75"></div>Base prompt<span class="tp-legval">118</span></div>
            <div class="tp-leg"><div class="tp-legdot" style="background:var(--bl);opacity:0.75"></div>Fragments<span class="tp-legval">97</span></div>
            <div class="tp-leg"><div class="tp-legdot" style="background:var(--pu);opacity:0.75"></div>Vary slots<span class="tp-legval">56</span></div>
            <div class="tp-leg"><div class="tp-legdot" style="background:var(--am);opacity:0.7"></div>Runtime overhead<span class="tp-legval">41</span></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp highlight_source(line) do
    line
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace("&#39;", "'")
    |> String.replace("&quot;", "\"")
    |> String.replace(~r/(@\w+)/, "<span class=\"vr\">\\1</span>")
    |> String.replace(
      ~r/(\bdo\b|\bend\b|\bif\b|\belse\b|\bcase\b|\bvary\b)/,
      "<span class=\"kw\">\\1</span>"
    )
    |> String.replace(~r/(\d+)/, "<span class=\"vl\">\\1</span>")
    |> String.replace(~r/(#.*)/, "<span class=\"cm\">\\1</span>")
    |> String.replace(~r/(\{.*?\})/, "<span class=\"fs\">\\1</span>")
    |> String.replace(~r/(\{\{.*?\}\})/, "<span class=\"fd\">\\1</span>")
  end

  defp format_param_value(nil), do: ""
  defp format_param_value(v) when is_binary(v), do: v
  defp format_param_value(v) when is_list(v), do: Enum.join(v, ", ")
  defp format_param_value(v) when is_map(v), do: Jason.encode!(v, pretty: true)
  defp format_param_value(v) when is_atom(v), do: to_string(v)
  defp format_param_value(v), do: to_string(v)

  defp mark_params(text, compile_params) do
    Enum.reduce(compile_params, text, fn {param_name, value}, acc ->
      if is_binary(value) and value != "" and String.length(value) > 1 do
        escaped_value = Regex.escape(value) |> IO.iodata_to_binary()
        pattern = ~r/(?<![^>\s])#{escaped_value}(?![<\s])/
        replacement = "<span class=\"pv\" title=\"@#{param_name}\">#{value}</span>"
        Regex.replace(pattern, acc, replacement)
      else
        acc
      end
    end)
  end

  defp mark_runtime_vars(text) do
    String.replace(text, ~r/(\{\{[^}]+\}\})/, "<span class=\"rtv\">\\1</span>")
  end

  def highlight_compiled_content(
        text,
        compile_params,
        collapsed_sections,
        vary_selections,
        section_popover
      )
      when is_binary(text) and is_map(compile_params) do
    result =
      parse_and_render_sections(
        text,
        compile_params,
        collapsed_sections,
        vary_selections,
        section_popover
      )

    result |> Phoenix.HTML.raw()
  end

  defp parse_and_render_sections(
         text,
         compile_params,
         collapsed_sections,
         vary_selections,
         section_popover
       ) do
    sections = split_into_sections(text)

    Enum.map_join(sections, "", fn section ->
      case section do
        {:section, type, indent, id, var_name, options_str, label, content} ->
          render_section(
            type,
            indent,
            id,
            var_name,
            options_str,
            label,
            content,
            compile_params,
            collapsed_sections,
            vary_selections,
            section_popover
          )

        {:text, content} ->
          render_content_with_earmark(content, compile_params, vary_selections)
      end
    end)
  end

  defp split_into_sections(text) do
    lines = String.split(text, "\n", trim: false)
    split_sections(lines, [], [])
  end

  defp split_sections([], [], sections) do
    sections
  end

  defp split_sections([], acc, sections) do
    sections ++ [{:text, Enum.join(Enum.reverse(acc), "\n")}]
  end

  defp split_sections([line | rest], acc, sections) do
    if String.trim_leading(line) |> String.starts_with?("[[section:") do
      section = parse_section_header(line)
      {content, remaining} = extract_section_content(rest, [])

      new_sections =
        sections ++
          [
            {:text, Enum.join(Enum.reverse(acc), "\n")},
            section |> put_elem(7, Enum.join(content, "\n"))
          ]

      split_sections(remaining, [], new_sections)
    else
      split_sections(rest, [line | acc], sections)
    end
  end

  defp extract_section_content(lines, acc, depth \\ 0)

  defp extract_section_content([], acc, _depth) do
    {Enum.reverse(acc), []}
  end

  defp extract_section_content([line | rest], acc, depth) do
    trimmed = String.trim(line)

    cond do
      String.starts_with?(trimmed, "[[section:") ->
        extract_section_content(rest, [line | acc], depth + 1)

      trimmed == "[[/section]]" ->
        if depth == 0 do
          {Enum.reverse(acc), rest}
        else
          extract_section_content(rest, [line | acc], depth - 1)
        end

      true ->
        extract_section_content(rest, [line | acc], depth)
    end
  end

  defp parse_section_header(line) do
    case Regex.run(~r/\[\[section:([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^\]]*)\]\]/, line) do
      [_, type, indent, id, var_name, options_str, label] ->
        {:section, type, String.to_integer(indent), id, var_name, options_str,
         String.trim_trailing(label, "]]"), ""}

      _ ->
        {:text, line}
    end
  end

  defp render_section(
         type,
         indent,
         id,
         var_name,
         options_str,
         label,
         content,
         compile_params,
         collapsed_sections,
         vary_selections,
         section_popover
       ) do
    options = if options_str == "", do: [], else: String.split(options_str, ",")
    is_collapsed = MapSet.member?(collapsed_sections, id)
    is_popover_open = section_popover == id
    indent_px = indent * 24

    color_class =
      case type do
        "branch" -> "ab-gr"
        "case" -> "ab-gr"
        "frag" -> "ab-bl"
        "vary" -> "ab-pu"
        _ -> "ab-mu"
      end

    final_label =
      if type == "vary" do
        selection = Map.get(vary_selections, label)
        selection_id = if is_map(selection), do: selection.id, else: selection || "?"
        "#{label} → #{selection_id}"
      else
        label
      end

    popover_html =
      if is_popover_open and options != [] do
        opts =
          Enum.map_join(options, "", fn opt ->
            """
            <div class="pf-row" phx-click="update_section_param" phx-value-var="#{var_name}" phx-value-val="#{opt}">
              <span class="pf-lbl">#{opt}</span>
            </div>
            """
          end)

        """
        <div class="popover dropdown-popover show" style="top: 24px; left: 0; width: 180px; font-style: normal;">
          <div class="pop-head" style="margin-bottom:4px">Select Value <span class="pop-close" phx-click="close_section_popover">×</span></div>
          <div class="pbody" style="padding: 2px;">#{opts}</div>
        </div>
        """
      else
        ""
      end

    rendered_content =
      if is_collapsed do
        ""
      else
        parse_and_render_sections(
          content,
          compile_params,
          collapsed_sections,
          vary_selections,
          section_popover
        )
      end

    """
    <div class="msec #{color_class}" style="margin-left: #{indent_px}px;">
      <div class="msec-label" phx-click="toggle_collapse" phx-value-group="#{id}">
        #{final_label}
        <span class="msec-chev #{if !is_collapsed, do: "open"}">›</span>
        #{popover_html}
      </div>
      <div class="msec-content#{if is_collapsed, do: " collapsed"}">
        #{rendered_content}
      </div>
    </div>
    """
  end

  defp render_content_with_earmark(content, compile_params, vary_selections) do
    case Earmark.as_html(content) do
      {:ok, %DotPrompt.Result{prompt: html}} ->
        html
        |> mark_params(compile_params)
        |> mark_runtime_vars()
        |> mark_vary_slots(vary_selections)

      _ ->
        content
        |> Phoenix.HTML.html_escape()
        |> Phoenix.HTML.safe_to_string()
        |> mark_params(compile_params)
        |> mark_runtime_vars()
        |> mark_vary_slots(vary_selections)
    end
  end

  defp mark_vary_slots(text, vary_selections) do
    # Handle raw quotes, HTML-escaped quotes, and smart (curly) quotes
    Regex.replace(
      ~r/\[\[vary:(?:\"|&quot;|”|“)(.*?)(?:\"|&quot;|”|“)\]\]/,
      text,
      fn _full, name ->
        selection = Map.get(vary_selections, name)

        if is_map(selection) do
          # Show the actual selected text in a nice Span
          "<span class=\"va\" title=\"Variant: #{selection.id}\">#{selection.text}</span>"
        else
          "<span class=\"va\">[#{selection || "slot — resolves after structural cache"}]</span>"
        end
      end
    )
  end

  def highlight_compiled_content(text, compile_params, collapsed_sections) do
    highlight_compiled_content(text, compile_params, collapsed_sections, %{}, nil)
  end

  def highlight_compiled_content(text, compile_params) do
    highlight_compiled_content(text, compile_params, MapSet.new(), %{}, nil)
  end

  def handle_event("resize", %{"id" => "nav-sidebar", "width" => width}, socket) do
    {:noreply, assign(socket, nav_width: width)}
  end

  def handle_event("resize", %{"id" => "ppane", "width" => width}, socket) do
    {:noreply, assign(socket, params_width: width)}
  end

  def handle_event("edit_line", %{"index" => index}, socket) do
    {:noreply, assign(socket, editing_line: String.to_integer(index))}
  end

  def handle_event("toggle_token_breakdown", _, socket) do
    {:noreply, assign(socket, token_breakdown_open: !socket.assigns.token_breakdown_open)}
  end

  def handle_event("toggle_folder", %{"folder" => folder}, socket) do
    collapsed_folders =
      if MapSet.member?(socket.assigns.collapsed_folders, folder) do
        MapSet.delete(socket.assigns.collapsed_folders, folder)
      else
        MapSet.put(socket.assigns.collapsed_folders, folder)
      end

    {:noreply, assign(socket, collapsed_folders: collapsed_folders)}
  end

  def handle_event("update_line", %{"index" => _index, "value" => _value}, socket) do
    # Can track dirty state here if needed
    {:noreply, socket}
  end

  def handle_event("save_line", %{"index" => index, "value" => value}, socket) do
    i = String.to_integer(index)

    content =
      if socket.assigns.view_mode == :source,
        do: socket.assigns.source_content,
        else: socket.assigns.compiled_content

    lines = String.split(content, "\n")

    new_lines = List.replace_at(lines, i - 1, value)
    new_content = Enum.join(new_lines, "\n")

    socket =
      if socket.assigns.view_mode == :source do
        # Save to file if source
        if socket.assigns.active_file do
          path = Path.join(DotPrompt.prompts_dir(), "#{socket.assigns.active_file}.prompt")
          File.write!(path, new_content)
        end

        assign(socket, source_content: new_content)
      else
        # Scratchpad edit for compiled
        assign(socket,
          compiled_content: new_content,
          scratch_edits: %{socket.assigns.active_file => true}
        )
      end

    {:noreply, assign(socket, editing_line: nil)}
  end

  def handle_event("save_line", %{"value" => value}, socket) do
    index = socket.assigns.editing_line

    if index do
      handle_event("save_line", %{"index" => to_string(index), "value" => value}, socket)
    else
      {:noreply, assign(socket, editing_line: nil)}
    end
  end

  def handle_event("focus_line", %{"index" => _index}, socket) do
    {:noreply, socket}
  end

  def handle_event("handle_keydown", %{"key" => "Enter", "index" => index}, socket) do
    {:noreply, assign(socket, editing_line: String.to_integer(index))}
  end

  def handle_event("handle_keydown", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, editing_line: nil)}
  end

  def handle_event("handle_keydown", _, socket) do
    {:noreply, socket}
  end

  def handle_event("handle_edit_keydown", %{"key" => "Enter"}, socket) do
    # Enter in the input confirms and closes editing
    {:noreply, assign(socket, editing_line: nil)}
  end

  def handle_event("handle_edit_keydown", %{"key" => "Escape"}, socket) do
    # Escape in the input cancels editing
    {:noreply, assign(socket, editing_line: nil)}
  end

  def handle_event("handle_edit_keydown", _, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_edit", _, socket) do
    if socket.assigns.scratch_edits do
      {:noreply, assign(socket, scratch_edits: nil)}
    else
      {:noreply, assign(socket, scratch_edits: %{socket.assigns.active_file => true})}
    end
  end

  def handle_event("toggle_collapse", %{"group" => group}, socket) do
    collapsed = socket.assigns.branch_annotations_collapsed

    new_collapsed =
      if MapSet.member?(collapsed, group) do
        MapSet.delete(collapsed, group)
      else
        MapSet.put(collapsed, group)
      end

    {:noreply, assign(socket, branch_annotations_collapsed: new_collapsed)}
  end

  def handle_event("select_file", %{"name" => name}, socket) do
    content = load_prompt_file(name)

    {active_schema, compile_params} =
      case DotPrompt.schema(name) do
        {:ok, schema} ->
          default_params =
            schema.params
            |> Enum.reject(fn {_, spec} -> spec.lifecycle == :runtime end)
            |> Enum.into(%{}, fn {k, spec} ->
              default =
                case spec.type do
                  :enum ->
                    values = Map.get(spec, :values, [])
                    if values != [] and values != nil, do: List.first(values), else: ""

                  :list_enum ->
                    values = Map.get(spec, :values, [])
                    if values != [] and values != nil, do: [List.first(values)], else: []

                  type when type in [:list, :list_str, :list_int] ->
                    values = Map.get(spec, :values, [])
                    if values != [] and values != nil, do: [List.first(values)], else: []

                  :int ->
                    case Map.get(spec, :range) do
                      [min, _max] -> min
                      _ -> 0
                    end

                  :bool ->
                    true

                  _ ->
                    Map.get(spec, :default, "")
                end

              {to_string(k), default}
            end)

          {schema, default_params}

        _ ->
          {nil, %{}}
      end

    {:noreply,
     socket
     |> assign(
       active_file: name,
       source_content: content,
       compiled_content: nil,
       compiled_annotations: [],
       used_vars: MapSet.new(),
       scratch_edits: nil,
       section_popover: nil,
       vary_selections: %{},
       view_mode: :source,
       error: nil,
       editing_line: nil,
       active_schema: active_schema,
       compile_params: compile_params
     )}
  end

  def handle_event("switch_tool", %{"tool" => tool}, socket) do
    tool_atom =
      case tool do
        "editor" -> :editor
        "telemetry" -> :telemetry
        "render" -> :render
        "cache" -> :cache
        _ -> :editor
      end

    socket =
      case tool_atom do
        :telemetry -> assign(socket, telemetry_events: DotPrompt.Telemetry.list_events())
        _ -> socket
      end

    {:noreply, assign(socket, active_tool: tool_atom)}
  end

  def handle_event("set_view", %{"view" => view}, socket) do
    view_atom =
      case view do
        "source" -> :source
        "compiled" -> :compiled
        "preview" -> :preview
        _ -> :source
      end

    socket = assign(socket, view_mode: view_atom)

    # Auto-compile when switching to compiled view
    if socket.assigns.active_file && view_atom == :compiled do
      do_compile(socket)
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_params", _, socket) do
    {:noreply, assign(socket, show_params_pane: !socket.assigns.show_params_pane)}
  end

  def handle_event("toggle_param_dropdown", %{"param" => param}, socket) do
    new_param = if socket.assigns.active_param_dropdown == param, do: nil, else: param
    {:noreply, assign(socket, active_param_dropdown: new_param)}
  end

  def handle_event("close_param_dropdown", _, socket) do
    {:noreply, assign(socket, active_param_dropdown: nil)}
  end

  def handle_event("toggle_section_popover", %{"id" => id}, socket) do
    new_id = if socket.assigns.section_popover == id, do: nil, else: id
    {:noreply, assign(socket, section_popover: new_id)}
  end

  def handle_event("close_section_popover", _, socket) do
    {:noreply, assign(socket, section_popover: nil)}
  end

  def handle_event("update_section_param", %{"var" => var, "val" => val}, socket) do
    # var can be like "user_level" or "_vary_intro"
    new_params =
      if String.starts_with?(var, "_vary_") do
        # It's a vary selection - ignore for now
        socket.assigns.compile_params
      else
        Map.put(socket.assigns.compile_params, var, val)
      end

    socket = assign(socket, compile_params: new_params, section_popover: nil)
    do_compile(socket)
  end

  def handle_event("update_source", %{"value" => content}, socket) do
    {:noreply, assign(socket, source_content: content)}
  end

  def handle_event("save_source", %{"value" => content}, socket) do
    if socket.assigns.active_file do
      path = Path.join(DotPrompt.prompts_dir(), "#{socket.assigns.active_file}.prompt")
      File.write!(path, content)
    end

    {:noreply, socket}
  end

  def handle_event("update_compile_param_form", params, socket) do
    # params is a map of string keys to string values
    # Filter out Phoenix form metadata (_unused_, _target)
    schema = socket.assigns.active_schema

    parsed_params =
      params
      |> Enum.reject(fn {name, _} -> String.starts_with?(name, "_") end)
      |> Enum.into(%{}, fn {name, value} ->
        # Normalize checkbox array keys (remove trailing [])
        normalized_name = String.replace(name, ~r/\[\]$/, "")
        spec = schema.params[normalized_name]
        type = if spec, do: spec.type, else: :str

        parsed_value =
          case {type, value} do
            {:bool, "true"} ->
              true

            {:bool, "false"} ->
              false

            {:int, v} when is_binary(v) ->
              case Integer.parse(v) do
                {n, ""} -> n
                _ -> v
              end

            {:list_str, v} when is_binary(v) ->
              v |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

            {:list, v} when is_binary(v) ->
              v |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

            {:list, v} when is_list(v) ->
              v

            {:list_enum, v} when is_list(v) ->
              v

            {:list_int, v} when is_binary(v) ->
              v
              |> String.split(",")
              |> Enum.map(&String.trim/1)
              |> Enum.reject(&(&1 == ""))
              |> Enum.map(fn x ->
                case Integer.parse(x) do
                  {n, ""} -> n
                  _ -> x
                end
              end)

            {:list_int, v} when is_list(v) ->
              Enum.map(v, fn x ->
                case Integer.parse(to_string(x)) do
                  {n, ""} -> n
                  _ -> x
                end
              end)

            _ ->
              value
          end

        {normalized_name, parsed_value}
      end)

    # Handle unchecked checkboxes - set them to false
    bool_params =
      schema.params
      |> Enum.filter(fn {_, s} -> s.type == :bool end)
      |> Enum.map(fn {k, _} -> k end)

    unchecked_bools = bool_params |> Enum.reject(fn p -> Map.has_key?(parsed_params, p) end)

    parsed_params = Enum.into(unchecked_bools, parsed_params, fn p -> {p, false} end)

    # Handle unchecked list checkboxes - set them to empty list
    list_checkbox_params =
      schema.params
      |> Enum.filter(fn {_, s} -> s.type in [:list, :list_enum] && s[:values] end)
      |> Enum.map(fn {k, _} -> k end)

    unchecked_lists =
      list_checkbox_params |> Enum.reject(fn p -> Map.has_key?(parsed_params, p) end)

    parsed_params = Enum.into(unchecked_lists, parsed_params, fn p -> {p, []} end)

    # Drop list params from old params so unchecked ones don't persist
    old_params_clean = Map.drop(socket.assigns.compile_params, list_checkbox_params)
    new_params = Map.merge(old_params_clean, parsed_params)

    socket = assign(socket, compile_params: new_params)

    if socket.assigns.active_file && socket.assigns.view_mode == :compiled do
      do_compile(socket)
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_seed", %{"seed" => ""}, socket) do
    socket = assign(socket, seed: 1)
    do_compile(socket)
  end

  def handle_event("update_seed", %{"seed" => seed}, socket) do
    socket = assign(socket, seed: String.to_integer(seed))
    do_compile(socket)
  end

  def handle_event("randomize_seed", _, socket) do
    seed = :rand.uniform(100_000)
    socket = assign(socket, seed: seed)
    do_compile(socket)
  end

  def handle_event("clear_seed", _, socket) do
    socket = assign(socket, seed: 1)
    do_compile(socket)
  end

  def handle_event("update_runtime_param", %{"name" => name, "value" => value}, socket) do
    DotPromptServer.RuntimeStorage.put_param(name, value, socket.assigns.active_file)
    new_params = Map.put(socket.assigns.runtime_params, name, value)
    {:noreply, assign(socket, runtime_params: new_params)}
  end

  def handle_event("compile", _, socket) do
    do_compile(socket)
  end

  def handle_event("open_runtime_popover", %{"param" => param}, socket) do
    {:noreply, assign(socket, runtime_popover: param)}
  end

  def handle_event("close_runtime_popover", _, socket) do
    {:noreply, assign(socket, runtime_popover: nil)}
  end

  def handle_event("save_fixture", %{"param" => param}, socket) do
    value = Map.get(socket.assigns.runtime_params, param, "")
    fixtures = Map.get(socket.assigns.runtime_fixtures, param, [])
    label = "Fixture #{length(fixtures) + 1}"

    DotPromptServer.RuntimeStorage.put_fixture(param, label, value)

    new_all = DotPromptServer.RuntimeStorage.get_all_fixtures()
    {:noreply, assign(socket, runtime_fixtures: new_all)}
  end

  def handle_event("load_fixture", %{"param" => param, "value" => value}, socket) do
    DotPromptServer.RuntimeStorage.put_param(param, value, socket.assigns.active_file)
    new_params = Map.put(socket.assigns.runtime_params, param, value)
    {:noreply, assign(socket, runtime_params: new_params, runtime_popover: nil)}
  end

  def handle_event("delete_fixture", %{"param" => param, "label" => label}, socket) do
    DotPromptServer.RuntimeStorage.delete_fixture(param, label)
    new_all = DotPromptServer.RuntimeStorage.get_all_fixtures()
    {:noreply, assign(socket, runtime_fixtures: new_all)}
  end

  def handle_event("expand_commit", _, socket) do
    {:noreply, assign(socket, commit_expanded: true)}
  end

  def handle_event("cancel_commit", _, socket) do
    {:noreply, assign(socket, commit_expanded: false)}
  end

  def handle_event("select_commit_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, commit_version_type: String.to_atom(type))}
  end

  def handle_event("discard_scratch", _, socket) do
    {:noreply, assign(socket, scratch_edits: nil, commit_expanded: false)}
  end

  def handle_event("full_render", _, socket) do
    if socket.assigns.active_file do
      params = prepare_params(socket.assigns.compile_params, socket.assigns.active_schema)
      runtime = socket.assigns.runtime_params
      content = socket.assigns.source_content
      opts = if socket.assigns.seed, do: [seed: socket.assigns.seed], else: []

      case DotPrompt.render(content, params, runtime, opts) do
        {:ok, %DotPrompt.Result{prompt: result}} ->
          # We'll use JS to update the output for better visual feedback
          {:noreply, push_event(socket, "update_render_output", %{content: result})}

        {:error, details} ->
          {:noreply, assign(socket, error: details.message)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("save_version", _, socket) do
    if socket.assigns.active_file do
      version = preview_version(1, socket.assigns.commit_version_type)
      new_filename = "#{socket.assigns.active_file}.#{version}"
      path = Path.join(DotPrompt.prompts_dir(), "#{new_filename}.prompt")

      content =
        if socket.assigns.view_mode == :source,
          do: socket.assigns.source_content,
          else: socket.assigns.compiled_content

      File.write!(path, content)

      {:noreply,
       socket
       |> assign(scratch_edits: nil, commit_expanded: false, prompts: DotPrompt.list_prompts())
       |> put_flash(:info, "Saved as new version: #{new_filename}")}
    else
      {:noreply, socket}
    end
  end

  def handle_continue([auto_compile: _file_name], socket) do
    do_compile(socket)
  end

  def handle_info(:auto_compile, socket) do
    do_compile(socket)
  end

  def handle_params(params, uri, socket) do
    tool_atom =
      cond do
        String.contains?(uri, "/telemetry") -> :telemetry
        String.contains?(uri, "/cache") -> :cache
        String.contains?(uri, "/stats") -> :cache
        String.contains?(uri, "/render") -> :render
        String.contains?(uri, "/viewer") -> :render
        true -> socket.assigns[:active_tool] || :editor
      end

    socket =
      if tool_atom == :telemetry do
        assign(socket, telemetry_events: DotPrompt.Telemetry.list_events())
      else
        socket
      end

    socket = assign(socket, active_tool: tool_atom)

    case params do
      %{"file" => file_list} ->
        file_name = if is_list(file_list), do: Enum.join(file_list, "/"), else: file_list

        if file_name != socket.assigns.active_file do
          content = load_prompt_file(file_name)
          runtime_params = load_runtime_params(file_name, params)
          {active_schema, compile_params, error_msg} = load_schema_and_params(file_name)

          socket =
            socket
            |> assign(
              active_file: file_name,
              source_content: content,
              compiled_content: nil,
              active_schema: active_schema,
              compile_params: compile_params,
              runtime_params: runtime_params,
              show_params_pane: true,
              active_param_dropdown: nil,
              error: error_msg,
              is_compiling: false,
              seed: nil
            )

          if error_msg do
            {:noreply, socket}
          else
            socket
            |> assign(
              active_file: file_name,
              active_schema: active_schema,
              compile_params: compile_params,
              runtime_params: runtime_params,
              source_content: content,
              used_vars: MapSet.new(),
              seed: nil
            )
            |> do_compile()
          end
        else
          {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  defp load_runtime_params(file_name, params) do
    stored_runtime = DotPromptServer.RuntimeStorage.get_params(file_name)

    url_runtime =
      case {params["name"], params["value"]} do
        {n, v} when is_binary(n) and is_binary(v) ->
          DotPromptServer.RuntimeStorage.put_param(n, v, file_name)
          %{n => v}

        _ ->
          %{}
      end

    Map.merge(stored_runtime, url_runtime)
  end

  defp load_schema_and_params(file_name) do
    case DotPrompt.schema(file_name) do
      {:ok, schema} ->
        default_params = build_default_params(schema.params)
        {schema, default_params, nil}

      {:error, %{message: msg}} ->
        {nil, %{}, msg}

      _ ->
        {nil, %{}, nil}
    end
  end

  defp build_default_params(params) do
    params
    |> Enum.reject(fn {_, spec} -> spec.lifecycle == :runtime end)
    |> Enum.into(%{}, fn {k, spec} ->
      default = get_param_default(spec)
      {to_string(k), default}
    end)
  end

  defp get_param_default(spec) do
    case spec.type do
      :enum ->
        values = Map.get(spec, :values, [])
        default = Map.get(spec, :default)

        cond do
          default != nil -> default
          values != [] and values != nil -> List.first(values)
          true -> ""
        end

      type when type in [:list, :list_enum, :list_str, :list_int] ->
        values = Map.get(spec, :values, [])
        default = Map.get(spec, :default)

        cond do
          is_list(default) -> default
          default != nil -> [default]
          values != [] and values != nil -> [List.first(values)]
          true -> []
        end

      :bool ->
        true

      _ ->
        Map.get(spec, :default, "")
    end
  end

  defp do_compile(socket) do
    if is_nil(socket.assigns.active_file) do
      {:noreply, socket}
    else
      socket = assign(socket, is_compiling: true, error: nil)

      # Merge compile and runtime params
      all_params = Map.merge(socket.assigns.compile_params, socket.assigns.runtime_params)
      params = prepare_params(all_params, socket.assigns.active_schema)

      content = socket.assigns.source_content
      opts = [annotated: true]
      seed = Map.get(socket.assigns, :seed)
      opts = if seed, do: [{:seed, seed} | opts], else: opts

      case DotPrompt.compile(content, params, opts) do
        {:ok, %DotPrompt.Result{} = res} ->
          {:noreply,
           socket
           |> assign(
             is_compiling: false,
             compiled_content: res.prompt,
             compiled_annotations: [],
             used_vars: res.metadata.used_vars,
             vary_selections: res.vary_selections,
             section_popover: nil,
             cache_hit: res.cache_hit,
             token_count: estimate_tokens(res.prompt),
             min_tokens: div(estimate_tokens(res.prompt), 2),
             max_tokens: estimate_tokens(res.prompt) + 50,
             vary_slots: map_size(res.vary_selections)
           )}

        {:error, details} ->
          {:noreply,
           socket
           |> assign(
             is_compiling: false,
             error: details.message
           )}
      end
    end
  end

  defp load_prompt_file(name) do
    path = Path.join(DotPrompt.prompts_dir(), "#{name}.prompt")

    if File.exists?(path) do
      File.read!(path)
    else
      ""
    end
  end

  defp prepare_params(params, schema) do
    params
    |> Enum.reject(fn {_, v} -> v == "" or v == nil end)
    |> Enum.into(%{}, fn {k, v} ->
      type = if schema, do: get_in(schema.params, [k, :type]), else: nil

      v =
        case {type, v} do
          {:bool, "false"} -> false
          {:bool, "true"} -> true
          _ -> v
        end

      {k, v}
    end)
  end

  defp estimate_tokens(text) when is_binary(text) do
    words = length(String.split(text))
    div(words * 4, 3)
  end

  def render_markdown(text) do
    case Earmark.as_html(text || "") do
      {:ok, html, _} ->
        html
        |> Phoenix.HTML.raw()

      _ ->
        text
        |> Phoenix.HTML.html_escape()
        |> Phoenix.HTML.safe_to_string()
        |> Phoenix.HTML.raw()
    end
  end

  defp preview_version(current, type) do
    case type do
      :patch -> "#{current}.1"
      :minor -> "#{current + 1}.0"
      :major -> "#{current + 1}.0.0"
    end
  end

  defp param_sort_weight(type) do
    case type do
      :list_enum -> 1
      :enum -> 2
      :bool -> 3
      :int -> 4
      _ -> 10
    end
  end

  defp build_tree(paths) do
    paths
    |> Enum.reduce(%{}, fn path, acc ->
      parts = String.split(path, "/")
      put_in_tree(acc, parts, path)
    end)
    |> sort_tree()
  end

  defp put_in_tree(tree, [name], full_path) do
    Map.put(tree, name, {:file, full_path})
  end

  defp put_in_tree(tree, [dir | rest], full_path) do
    subtree = Map.get(tree, dir, %{})
    Map.put(tree, dir, put_in_tree(subtree, rest, full_path))
  end

  defp sort_tree(tree) do
    tree
    |> Enum.sort(fn {name1, content1}, {name2, content2} ->
      case {content1, content2} do
        {{:file, _}, {:file, _}} -> name1 < name2
        {{:file, _}, _} -> false
        {_, {:file, _}} -> true
        {_, _} -> name1 < name2
      end
    end)
    |> Enum.map(fn {name, content} ->
      case content do
        {:file, _} = f -> {name, f}
        subtree -> {name, sort_tree(subtree)}
      end
    end)
  end

  defp render_tree(assigns) do
    ~H"""
    <%= for {name, content} <- @tree do %>
      <%= case content do %>
        <% {:file, path} -> %>
          <.link patch={"/prompts/#{path}"} class={["fr", if(path == @active_file, do: "on")]}>
            <div class="fdot"></div><%= name %>
          </.link>
        <% subtree -> %>
          <% 
            folder_path = if @parent_path == "", do: name, else: "#{@parent_path}/#{name}"
            is_collapsed = MapSet.member?(@collapsed_folders, folder_path)
          %>
          <div class="fdir" phx-click="toggle_folder" phx-value-folder={folder_path}>
            <span style="font-size: 8px; width: 10px; display: inline-block;"><%= if is_collapsed, do: "▶", else: "▼" %></span> <%= name %>
          </div>
          <%= if !is_collapsed do %>
            <div class="nested-tree" style="margin-left: 10px; border-left: 1px solid rgba(255,255,255,0.05); margin-bottom: 2px;">
              <.render_tree 
                tree={subtree} 
                active_file={@active_file} 
                collapsed_folders={@collapsed_folders} 
                parent_path={folder_path}
              />
            </div>
          <% end %>
      <% end %>
    <% end %>
    """
  end
end
