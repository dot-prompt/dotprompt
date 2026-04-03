defmodule DotPromptServerWeb.SchemaController do
  use DotPromptServerWeb, :controller

  def show(conn, %{"prompt" => prompt} = params) do
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

    case DotPrompt.schema(prompt, major) do
      {:ok, schema} ->
        json(conn, schema)

      {:error, details} ->
        conn
        |> put_status(:not_found)
        |> json(details)
    end
  rescue
    e ->
      conn
      |> put_status(:not_found)
      |> json(%{error: "not_found", message: Exception.message(e)})
  end
end
