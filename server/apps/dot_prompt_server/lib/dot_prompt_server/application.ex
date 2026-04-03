defmodule DotPromptServer.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    disable_ui = System.get_env("DISABLE_UI") == "true"

    children = [
      {Phoenix.PubSub, name: DotPromptServer.PubSub},
      {DotPromptServer.RuntimeStorage, []},
      if(disable_ui, do: nil, else: DotPromptServerWeb.Endpoint),
      {DotPromptServer.FileWatcher, []}
    ]
    |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: DotPromptServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    DotPromptServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
