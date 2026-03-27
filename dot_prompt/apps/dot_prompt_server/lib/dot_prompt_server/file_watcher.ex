defmodule DotPromptServer.FileWatcher do
  @moduledoc """
  Watches the prompts directory for changes and invalidates cache accordingly.
  """

  use GenServer
  require Logger

  alias DotPrompt.Cache.Fragment

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    prompts_dir = Keyword.get(opts, :prompts_dir, Application.get_env(:dot_prompt, :prompts_dir))
    prompts_dir = Path.expand(prompts_dir)

    File.mkdir_p(prompts_dir)

    {:ok, watcher_pid} = FileSystem.start_link(dirs: [prompts_dir])
    FileSystem.subscribe(watcher_pid)

    {:ok, %{watcher_pid: watcher_pid, prompts_dir: prompts_dir}}
  end

  @impl true
  def handle_info({:file_event, _pid, {path, events}}, state) do
    if :modified in events or :created in events do
      if String.ends_with?(path, ".prompt") do
        # Correctly resolve relative path for nested prompts
        prompt_name =
          path
          |> Path.relative_to(state.prompts_dir)
          |> String.replace_suffix(".prompt", "")

        Logger.info("dot-prompt: invalidating cache for #{prompt_name} due to file change")
        DotPrompt.invalidate_cache(prompt_name)
        Fragment.invalidate_path(prompt_name)

        Phoenix.PubSub.broadcast(DotPromptServer.PubSub, "events", {:file_change, prompt_name})
      end
    end

    {:noreply, state}
  end

  def handle_info({:file_event, _pid, :stop}, state) do
    {:noreply, state}
  end
end
