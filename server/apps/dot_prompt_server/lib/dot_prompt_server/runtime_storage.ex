defmodule DotPromptServer.RuntimeStorage do
  @moduledoc """
  In-memory storage for runtime values (parameters and fixtures) that persists
  to a local JSON file to survive application restarts without a database.
  """
  use GenServer
  require Logger

  @name __MODULE__

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Saves a runtime parameter value.
  If `file_name` is provided, it's saved specifically for that file.
  Otherwise, it's saved as a global default.
  """
  def put_param(name, value, file_name \\ nil) do
    GenServer.cast(@name, {:put_param, name, value, file_name})
  end

  @doc """
  Gets all runtime parameters for a specific file, merged with global defaults.
  """
  def get_params(file_name) do
    GenServer.call(@name, {:get_params, file_name})
  end

  @doc """
  Saves a fixture (label + value) for a specific parameter.
  """
  def put_fixture(param_name, label, value) do
    GenServer.cast(@name, {:put_fixture, param_name, label, value})
  end

  @doc """
  Deletes a specific fixture.
  """
  def delete_fixture(param_name, label) do
    GenServer.cast(@name, {:delete_fixture, param_name, label})
  end

  @doc """
  Gets all fixtures for a parameter.
  """
  def get_fixtures(param_name) do
    GenServer.call(@name, {:get_fixtures, param_name})
  end

  @doc """
  Gets all fixtures for all parameters.
  """
  def get_all_fixtures do
    GenServer.call(@name, :get_all_fixtures)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("[RuntimeStorage] Starting...")
    state = load_state()
    {:ok, state}
  end

  @impl true
  def handle_cast({:put_param, name, value, nil}, state) do
    new_global = Map.put(state.global_params, to_string(name), value)
    new_state = %{state | global_params: new_global}
    save_state(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:put_param, name, value, file_name}, state) do
    file_map = Map.get(state.file_params, file_name, %{})
    new_file_map = Map.put(file_map, to_string(name), value)
    new_file_params = Map.put(state.file_params, file_name, new_file_map)
    new_state = %{state | file_params: new_file_params}
    save_state(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:put_fixture, param_name, label, value}, state) do
    fixtures = Map.get(state.fixtures, to_string(param_name), [])
    # Remove existing with same label if any
    filtered = Enum.reject(fixtures, fn f -> f["label"] == label or f[:label] == label end)
    new_fixtures = filtered ++ [%{"label" => label, "value" => value}]
    new_state = %{state | fixtures: Map.put(state.fixtures, to_string(param_name), new_fixtures)}
    save_state(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:delete_fixture, param_name, label}, state) do
    fixtures = Map.get(state.fixtures, to_string(param_name), [])
    new_fixtures = Enum.reject(fixtures, fn f -> f["label"] == label or f[:label] == label end)
    new_state = %{state | fixtures: Map.put(state.fixtures, to_string(param_name), new_fixtures)}
    save_state(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_params, file_name}, _from, state) do
    file_map = Map.get(state.file_params, file_name, %{})
    # Merge global params with file-specific params (file-specific wins)
    merged = Map.merge(state.global_params, file_map)
    {:reply, merged, state}
  end

  @impl true
  def handle_call({:get_fixtures, param_name}, _from, state) do
    raw_fixtures = Map.get(state.fixtures, to_string(param_name), [])

    formatted =
      Enum.map(raw_fixtures, fn f -> {f["label"] || f[:label], f["value"] || f[:value]} end)

    {:reply, formatted, state}
  end

  @impl true
  def handle_call(:get_all_fixtures, _from, state) do
    # Format all fixtures to {label, value} for DevUI compatibility
    formatted =
      state.fixtures
      |> Enum.into(%{}, fn {p, fs} ->
        {p, Enum.map(fs, fn f -> {f["label"] || f[:label], f["value"] || f[:value]} end)}
      end)

    {:reply, formatted, state}
  end

  # Helper Functions

  defp storage_file do
    Path.join(File.cwd!(), ".runtime_storage.json")
  end

  defp load_state do
    path = storage_file()

    if File.exists?(path) do
      case File.read(path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, data} ->
              Logger.info("[RuntimeStorage] Loaded state from #{path}")

              %{
                global_params: Map.get(data, "global_params", %{}),
                file_params: Map.get(data, "file_params", %{}),
                fixtures: Map.get(data, "fixtures", %{})
              }

            _ ->
              Logger.warning("[RuntimeStorage] Failed to decode JSON, using default state")
              default_state()
          end

        _ ->
          default_state()
      end
    else
      Logger.info("[RuntimeStorage] No storage file found at #{path}, using default state")
      default_state()
    end
  end

  defp save_state(state) do
    path = storage_file()

    case Jason.encode(state) do
      {:ok, json} ->
        File.write(path, json)
        {:ok, state}

      {:error, reason} ->
        Logger.error("[RuntimeStorage] Failed to save state: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp default_state do
    %{global_params: %{}, file_params: %{}, fixtures: %{}}
  end
end
