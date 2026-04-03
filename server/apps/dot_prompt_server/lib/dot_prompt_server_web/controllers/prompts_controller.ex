defmodule DotPromptServerWeb.PromptsController do
  use DotPromptServerWeb, :controller

  def index(conn, _params) do
    json(conn, %{prompts: DotPrompt.list_prompts()})
  end

  def collections(conn, _params) do
    json(conn, %{collections: DotPrompt.list_collections()})
  end
end
