defmodule DotPromptServerWeb.CompileController do
  use DotPromptServerWeb, :controller

  def compile(conn, %{"prompt" => prompt, "params" => params} = body) do
    opts =
      []
      |> maybe_put(:seed, body["seed"])
      |> maybe_put(:major, body["major"])

    case DotPrompt.compile(prompt, params, opts) do
      {:ok, %DotPrompt.Result{} = result} ->
        json(conn, %{
          template: result.prompt,
          cache_hit: result.cache_hit,
          compiled_tokens: result.compiled_tokens,
          vary_selections: result.vary_selections,
          response_contract: result.response_contract,
          major: result.major,
          version: result.version,
          params: result.metadata.params,
          warnings: result.metadata.warnings
        })

      {:error, details} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(details)
    end
  rescue
    e ->
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "compile_error", message: Exception.message(e)})
  end

  # Handle missing required params - return 422
  def compile(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "missing_required_params", message: "prompt and params are required"})
  end

  defp maybe_put(list, _key, nil), do: list
  defp maybe_put(list, key, value), do: [{key, value} | list]
end
