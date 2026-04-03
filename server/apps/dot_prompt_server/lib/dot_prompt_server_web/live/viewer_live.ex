defmodule DotPromptServerWeb.ViewerLive do
  use DotPromptServerWeb, :live_view
  import Phoenix.HTML
  require Logger

  def mount(_params, _session, socket) do
    prompts = DotPrompt.list_prompts()

    {:ok,
     assign(socket,
       prompts: prompts,
       selected_prompt: nil,
       params_input: "",
       runtime_input: "",
       compiled_template: nil,
       final_output: nil,
       error: nil,
       sidebar_width: 256,
       input_width: 400,
       active_dropdown: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="shell">
      <!-- Sidebar / Nav -->
      <div id="sidebar" style={"width: #{@sidebar_width}px;"} class="nav border-r border-gray-800">
        <div class="nav-head">
          <span class="logo"><em>.</em>prompt</span>
          <span class="epill">dev</span>
        </div>
        <div class="ns">
          <div class="nl">Prompts</div>
          <div class="fdir">prompts/</div>
          <%= for prompt <- @prompts do %>
            <button 
              class={"fr #{if @selected_prompt == prompt, do: "on", else: ""}"}
              phx-click="select_prompt" 
              phx-value-name={prompt}
            >
              <div class="fdot"></div>
              <%= Path.basename(prompt) %>
              <%= if @selected_prompt == prompt do %>
                <div class="famd"></div>
              <% end %>
            </button>
          <% end %>
        </div>
        
        <div class="ndiv"></div>
        
        <div class="ns">
          <div class="nl">Tools</div>
          <button class="ni on">
            <svg viewBox="0 0 13 13" fill="none"><rect x="1" y="1" width="11" height="11" rx="2" stroke="currentColor" stroke-width="1.1"/><path d="M4 5l2 2-2 2M7.5 9h2" stroke="currentColor" stroke-width="1.1" stroke-linecap="round"/></svg>Editor
          </button>
          <button class="ni">
            <svg viewBox="0 0 13 13" fill="none"><path d="M2 4h9M2 6.5h6M2 9h4" stroke="currentColor" stroke-width="1.1" stroke-linecap="round"/></svg>Render test
          </button>
        </div>

        <div class="nbot">
          <button class="ni" style="font-size:11px">
            <svg viewBox="0 0 13 13" fill="none"><circle cx="6.5" cy="4" r="2" stroke="currentColor" stroke-width="1.1"/><path d="M2 11c0-2.2 2-4 4.5-4s4.5 1.8 4.5 4" stroke="currentColor" stroke-width="1.1" stroke-linecap="round"/></svg>Docs
          </button>
        </div>
      </div>

      <div id="sidebar-resizer" phx-hook="Resizable" data-target-id="sidebar" class="resizer"></div>

      <!-- Main Content -->
      <div class="main">
        <%= if @selected_prompt do %>
          <div class="tbar">
            <div class="vtog">
              <button class={"vb #{if is_nil(@final_output), do: "on", else: ""}"} phx-click="compile">Compiled</button>
              <button class={"vb #{if @final_output, do: "on", else: ""}"} phx-click="render">Full Render</button>
            </div>
            <span class="tfile"><%= @selected_prompt %>.prompt</span>
            <span class="tver">v1</span>
            
            <div class="tright">
              <button class="btn btn-edit">Edit</button>
              <button class="btn">Params ›</button>
              <button class="btn">Tokens ›</button>
            </div>
          </div>

          <div class="work">
            <!-- Editor Pane -->
            <div class="epane">
              <%= if @error do %>
                <div class="error-banner">
                  <div class="error-icon">!</div>
                  <div class="error-content">
                    <div class="error-type">Error</div>
                    <div class="error-message"><%= @error %></div>
                  </div>
                </div>
              <% end %>

              <div class="cscroll">
                <%= if @final_output do %>
                  <div class="ced p-4">
                    <pre class="text-green-400 whitespace-pre-wrap text-sm" style="font-family: var(--mo);"><code><%= @final_output %></code></pre>
                  </div>
                <% else %>
                  <%= if @compiled_template do %>
                    <div class="ced flex flex-col">
                      <%= for line <- parse_annotated_template(@compiled_template) do %>
                        <div class={"cl flex-shrink-0 #{if line.ann, do: "ann", else: ""} #{if line.hl, do: "hl-#{line.hl}", else: ""}"}>
                          <span class="ln"><%= line.n %></span>
                          <div class="cc" 
                            phx-click={if line.ann and line.var != "", do: "toggle_dropdown"} 
                            phx-value-var={line.var}
                          >
                            <%= raw(line.h) %>
                            <%= if line.ann and @active_dropdown == line.var do %>
                              <div class="dd-menu open" style="top: 100%; left: 0; min-width: 150px; position: absolute;">
                                <%= for opt <- String.split(line.options, ",", trim: true) do %>
                                  <div class="dd-option" phx-click="select_param_value" phx-value-var={line.var} phx-value-val={opt}>
                                    <%= opt %>
                                  </div>
                                <% end %>
                              </div>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% else %>
                    <div class="h-full flex items-center justify-center text-gray-600">
                      Click Compiled or Full Render to see output
                    </div>
                  <% end %>
                <% end %>
              </div>

              <div class="sbar">
                <div class="st"><span class="slb">tokens</span><span class="sv sv-gr">~<%= if @final_output, do: count_tokens(@final_output), else: count_tokens(@compiled_template || "") %></span></div>
                <div class="st"><span class="slb">cache</span><span class="sv" style="color:var(--gr)">hit</span></div>
                <div class="sright">
                  <div style="display:flex;align-items:center;gap:5px">
                    <div class="sconndot"></div>
                    <span class="slb" style="color:var(--mu)">:4040</span>
                  </div>
                </div>
              </div>
            </div>

            <div id="input-resizer" phx-hook="Resizable" data-target-id="input-panel" class="resizer"></div>

            <!-- Params Pane (Simplified for now) -->
            <div id="input-panel" style={"width: #{@input_width}px;"} class="ppane">
              <div class="ph">
                <span class="ptitle">Params</span>
              </div>
              <div class="pbody">
                <div class="pgl">Compile-time</div>
                <div class="pr">
                  <label class="plbl"><span class="pn">Params JSON</span></label>
                  <textarea 
                    phx-blur="update_params"
                    class="pi h-32" style="height: 120px; resize: vertical;"
                    placeholder='{"user_level": "beginner"}'
                  ><%= @params_input %></textarea>
                </div>

                <div class="pdiv"></div>
                
                <div class="pgl">Runtime</div>
                <div class="pr">
                  <label class="plbl"><span class="pn">Runtime JSON</span></label>
                  <textarea 
                    phx-blur="update_runtime"
                    class="pi h-32" style="height: 120px; resize: vertical;"
                    placeholder='{"user_message": "Hello"}'
                  ><%= @runtime_input %></textarea>
                </div>
              </div>
            </div>
          </div>
        <% else %>
          <div class="h-screen flex items-center justify-center text-gray-500">
            <div class="text-center">
              <div class="logo mb-4" style="font-size: 24px;"><em>.</em>prompt</div>
              <p>Select a prompt from the sidebar to begin.</p>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("select_prompt", %{"name" => name}, socket) do
    {:noreply,
     assign(socket, selected_prompt: name, compiled_template: nil, final_output: nil, error: nil)}
  end

  def handle_event("update_params", %{"value" => val}, socket) do
    {:noreply, assign(socket, params_input: val)}
  end

  def handle_event("update_runtime", %{"value" => val}, socket) do
    {:noreply, assign(socket, runtime_input: val)}
  end

  def handle_event("compile", _, socket) do
    params = parse_json(socket.assigns.params_input)

    case DotPrompt.compile(socket.assigns.selected_prompt, params, annotated: true) do
      {:ok, %DotPrompt.Result{prompt: template}} ->
        # Debug: check if sections exist in the template
        if !String.contains?(template, "[[section") do
          Logger.warning(
            "Compiled template does not contain annotations even though annotated: true was passed."
          )
        end

        {:noreply, assign(socket, compiled_template: template, final_output: nil, error: nil)}

      {:error, details} ->
        {:noreply, assign(socket, error: details.message)}
    end
  end

  def handle_event("render", _, socket) do
    params = parse_json(socket.assigns.params_input)
    runtime = parse_json(socket.assigns.runtime_input)

    case DotPrompt.render(socket.assigns.selected_prompt, params, runtime) do
      {:ok, %DotPrompt.Result{prompt: result}} ->
        {:noreply, assign(socket, final_output: result, error: nil)}

      {:error, details} ->
        {:noreply, assign(socket, error: details.message)}
    end
  end

  def handle_event("resize", %{"id" => "sidebar", "width" => width}, socket) do
    {:noreply, assign(socket, sidebar_width: width)}
  end

  def handle_event("resize", %{"id" => "input-panel", "width" => width}, socket) do
    {:noreply, assign(socket, input_width: width)}
  end

  def handle_event("toggle_dropdown", %{"var" => var}, socket) do
    new_active = if socket.assigns.active_dropdown == var, do: nil, else: var
    {:noreply, assign(socket, active_dropdown: new_active)}
  end

  def handle_event("select_param_value", %{"var" => var, "val" => val}, socket) do
    params = parse_json(socket.assigns.params_input)
    # Val might be "true"/"false" or a number, try to parse
    parsed_val =
      case val do
        "true" ->
          true

        "false" ->
          false

        _ ->
          case Integer.parse(val) do
            {n, ""} -> n
            _ -> val
          end
      end

    new_params = Map.put(params, var, parsed_val)
    new_params_json = Jason.encode!(new_params, pretty: true)

    # Auto-compile with new params
    socket = assign(socket, params_input: new_params_json, active_dropdown: nil)
    handle_event("compile", %{}, socket)
  end

  defp parse_json(""), do: %{}

  defp parse_json(str) do
    case Jason.decode(str) do
      {:ok, map} -> map
      _ -> %{}
    end
  end

  defp parse_annotated_template(nil), do: []

  defp parse_annotated_template(template) do
    template
    # Handle all line ending types
    |> String.split(~r/\R/)
    |> Enum.flat_map(fn line ->
      trimmed = String.trim(line)

      case Regex.run(~r/\[\[section:(.*?):(\d+):(\d+):(.*?):(.*?):(.*?)]]/, trimmed) do
        [_, type, _indent, _count, var, options, label] ->
          [
            %{
              n: 0,
              ann: true,
              var: var,
              options: options,
              h:
                ~s|<div class="ab ab-#{color_for_type(type)}">#{label}</div> <span class="chev">›</span>|,
              hl: nil
            }
          ]

        _ ->
          if String.contains?(line, "[[/section]]") do
            []
          else
            # 1. Handle special placeholders first (structural markers)
            h =
              String.replace(
                line,
                ~r/\[\[vary:(.*?)\]\]/,
                ~s|<span class="va">[slot — resolves after structural cache]</span>|
              )

            # 2. Single pass highlighting for content
            tokens = ~r/(@\w+)|(\{\w+\})|(\d+)|("(?:[^"\\\\]|\\\\.)*")|(#.*$)/

            h =
              Regex.replace(tokens, h, fn
                "@" <> _ = var, _, _, _, _, _ -> ~s|<span class="vr">#{var}</span>|
                "{" <> _ = frag, _, _, _, _, _ -> ~s|<span class="fs">#{frag}</span>|
                "\"" <> _ = str, _, _, _, _, _ -> ~s|<span class="vl">#{str}</span>|
                "#" <> _ = cm, _, _, _, _, _ -> ~s|<span class="cm">#{cm}</span>|
                num, _, _, _, _, _ -> ~s|<span class="vl">#{num}</span>|
              end)

            [%{n: 0, ann: false, var: "", options: "", h: h, hl: nil}]
          end
      end
    end)
    # Re-index to ensure sequential line numbers after filtering
    |> Enum.with_index(1)
    |> Enum.map(fn {line, idx} -> %{line | n: idx} end)
  end

  defp color_for_type("branch"), do: "gr"
  defp color_for_type("case"), do: "gr"
  defp color_for_type("vary"), do: "pu"
  defp color_for_type("frag"), do: "bl"
  defp color_for_type(_), do: "mu"

  defp count_tokens(text) when is_binary(text) do
    words = String.split(String.trim(text))
    div(length(words) * 4, 3)
  end
end
