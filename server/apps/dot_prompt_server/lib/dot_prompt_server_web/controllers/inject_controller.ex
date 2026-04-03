defmodule DotPromptServerWeb.InjectController do
  use DotPromptServerWeb, :controller

  def inject(conn, %{"template" => template, "runtime" => runtime}) do
    result = DotPrompt.inject(template, runtime)
    injected_tokens = count_tokens(result)

    json(conn, %{
      prompt: result,
      injected_tokens: injected_tokens
    })
  rescue
    e ->
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "inject_error", message: Exception.message(e)})
  end

  # Handle missing required params - return 422
  def inject(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "missing_required_params", message: "template and runtime are required"})
  end

  defp count_tokens(text) when is_binary(text) do
    words = String.split(String.trim(text))
    div(length(words) * 4, 3)
  end
end
