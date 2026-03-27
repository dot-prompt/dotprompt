defmodule DotPromptServerWeb.RenderController do
  use DotPromptServerWeb, :controller

  def render(conn, %{"prompt" => prompt, "params" => params, "runtime" => runtime} = body) do
    opts =
      []
      |> maybe_put(:seed, body["seed"])
      |> maybe_put(:major, body["major"])

    case DotPrompt.render(prompt, params, runtime, opts) do
      {:ok, %DotPrompt.Result{} = result} ->
        json(conn, %{
          prompt: result.prompt,
          cache_hit: result.cache_hit,
          compiled_tokens: result.compiled_tokens,
          vary_selections: result.vary_selections,
          injected_tokens: result.injected_tokens,
          response_contract: result.response_contract
        })

      {:error, details} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(details)

      _ ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "internal_error", message: "Unexpected render result"})
    end
  end

  defp maybe_put(list, _key, nil), do: list
  defp maybe_put(list, key, value), do: [{key, value} | list]
end
