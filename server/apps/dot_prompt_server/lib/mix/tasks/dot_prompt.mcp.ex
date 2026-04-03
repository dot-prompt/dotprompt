defmodule Mix.Tasks.DotPrompt.Mcp do
  @moduledoc """
  Mix task to run the MCP server for dot-prompt.
  """
  use Mix.Task

  alias DotPromptServer.MCP.Server

  @shortdoc "Runs the MCP server"

  def run(_args) do
    Mix.Task.run("app.start")
    Server.start()
  end
end
