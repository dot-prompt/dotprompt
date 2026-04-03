defmodule DotPrompt.Compiler.FragmentExpander.Dynamic do
  @moduledoc """
  Expands dynamic fragments {{}}. These interpolate runtime variables from params.
  Dynamic fragments are NOT cached - they're evaluated fresh each request.
  """

  @spec expand(String.t(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def expand(fragment_path, params) do
    var_name = String.trim(fragment_path, "{") |> String.trim("}")

    # Try string key first (from JSON/API), then atom key (Elixir maps)
    value =
      case Map.fetch(params, var_name) do
        {:ok, v} ->
          v

        :error ->
          try do
            case Map.fetch(params, String.to_atom(var_name)) do
              {:ok, v} -> v
              :error -> nil
            end
          rescue
            _ -> nil
          end
      end

    case value do
      nil ->
        {:error, "variable #{var_name} not found in params"}

      v when is_list(v) ->
        {:ok, Enum.join(v, ", ")}

      v ->
        {:ok, to_string(v)}
    end
  end
end
