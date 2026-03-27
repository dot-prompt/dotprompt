defmodule DotPromptServerWeb.EventController do
  @moduledoc """
  Controller for handling SSE (Server-Sent Events).
  Streams real-time updates for prompt file changes and other container events.
  """
  use DotPromptServerWeb, :controller

  @doc """
  Establishes an SSE stream.
  Subscribes to the `events` PubSub topic and chunks data to the client.
  """
  def index(conn, _params) do
    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    Phoenix.PubSub.subscribe(DotPromptServer.PubSub, "events")

    # Initial keep-alive or sync event could be sent here
    {:ok, conn} = chunk(conn, "data: {\"type\": \"connected\"}\n\n")

    stream_events(conn)
  end

  defp stream_events(conn) do
    receive do
      {:file_change, prompt_name} ->
        data = Jason.encode!(%{type: "file_change", prompt: prompt_name})
        case chunk(conn, "data: #{data}\n\n") do
          {:ok, conn} -> stream_events(conn)
          {:error, _} -> conn
        end

      _ ->
        stream_events(conn)
    after
      30_000 ->
        # Keep-alive
        case chunk(conn, ": ping\n\n") do
          {:ok, conn} -> stream_events(conn)
          {:error, _} -> conn
        end
    end
  end
end
