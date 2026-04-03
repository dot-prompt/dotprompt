defmodule DotPrompt.Cache.Fragment do
  @moduledoc """
  ETS-based cache for static fragment compilation.
  """
  use GenServer

  @table :dot_prompt_fragment_cache

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(@table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: :auto
    ])

    {:ok, %{}}
  end

  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :error
    end
  end

  def put(key, value) do
    :ets.insert(@table, {key, value})
  end

  def invalidate_path(path) do
    # Using match_delete is more efficient than foldl + delete if we can structure the key
    # But currently keys are hashes. If we want path-based invalidation,
    # we need to include path in the key or use a secondary index.
    # For now, keeping foldl but making it slightly safer.
    keys =
      :ets.foldl(
        fn {k, _}, acc ->
          if is_binary(k) and String.contains?(k, path) do
            [k | acc]
          else
            acc
          end
        end,
        [],
        @table
      )

    Enum.each(keys, fn k -> :ets.delete(@table, k) end)
    :ok
  end

  def clear do
    :ets.delete_all_objects(@table)
  end

  def count do
    case :ets.info(@table, :size) do
      :undefined -> 0
      size -> size
    end
  end
end
