defmodule Chatterbex.Server do
  @moduledoc """
  GenServer managing the Python port for Chatterbox TTS operations.

  This server maintains a persistent connection to a Python process
  that loads and runs Chatterbox models.
  """

  use GenServer

  require Logger

  @default_timeout :timer.minutes(5)

  defstruct [:port, :model, :device, :pending, :buffer]

  # Client API

  @doc false
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  def generate(server, text, opts \\ [], timeout \\ @default_timeout) do
    GenServer.call(server, {:generate, text, opts}, timeout)
  end

  @doc false
  def stop(server) do
    GenServer.stop(server)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    model = Keyword.get(opts, :model, :turbo)
    device = Keyword.get(opts, :device, "cuda")

    state = %__MODULE__{
      model: model,
      device: device,
      pending: nil,
      buffer: ""
    }

    case start_port(state) do
      {:ok, port} ->
        state = %{state | port: port}

        case init_model(state) do
          :ok -> {:ok, state}
          {:error, reason} -> {:stop, reason}
        end

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:generate, text, opts}, from, state) do
    request = build_generate_request(text, opts, state.model)

    case send_request(state.port, request) do
      :ok ->
        {:noreply, %{state | pending: from}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
    # Complete line received - parse it
    data = state.buffer <> line

    case parse_response(data) do
      {:ok, response, _rest} ->
        state = %{state | buffer: ""}
        handle_response(response, state)

      :incomplete ->
        # Shouldn't happen with complete lines, but handle gracefully
        {:noreply, %{state | buffer: ""}}
    end
  end

  @impl true
  def handle_info({port, {:data, {:noeol, partial}}}, %{port: port} = state) do
    # Partial line - buffer it
    {:noreply, %{state | buffer: state.buffer <> partial}}
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.error("Chatterbex Python process exited with status #{status}")

    if state.pending do
      GenServer.reply(state.pending, {:error, :port_closed})
    end

    {:stop, {:port_exit, status}, %{state | port: nil, pending: nil}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{port: port}) when is_port(port) do
    Port.close(port)
  end

  def terminate(_reason, _state), do: :ok

  # Private Functions

  defp start_port(state) do
    python_script = python_script_path()

    unless File.exists?(python_script) do
      {:error, {:missing_python_script, python_script}}
    else
      port =
        Port.open({:spawn_executable, System.find_executable("python3")}, [
          :binary,
          :exit_status,
          {:args, [python_script]},
          {:env, python_env(state)},
          {:line, 1_000_000}
        ])

      {:ok, port}
    end
  end

  defp python_script_path do
    :chatterbex
    |> :code.priv_dir()
    |> Path.join("python/chatterbex_bridge.py")
  end

  defp python_env(_state) do
    [
      {~c"PYTHONUNBUFFERED", ~c"1"}
    ]
  end

  defp init_model(state) do
    request = %{
      "type" => "init",
      "model" => model_name(state.model),
      "device" => state.device
    }

    case send_request(state.port, request) do
      :ok ->
        wait_for_init_response(state.port, "")

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp wait_for_init_response(port, buffer) do
    receive do
      {^port, {:data, {:eol, line}}} ->
        data = buffer <> line

        case parse_response(data) do
          {:ok, %{"status" => "ok"}, _} -> :ok
          {:ok, %{"status" => "error", "error" => error}, _} -> {:error, error}
          _ -> {:error, :init_failed}
        end

      {^port, {:data, {:noeol, partial}}} ->
        wait_for_init_response(port, buffer <> partial)
    after
      :timer.minutes(5) ->
        {:error, :init_timeout}
    end
  end

  defp model_name(:turbo), do: "turbo"
  defp model_name(:english), do: "english"
  defp model_name(:multilingual), do: "multilingual"

  defp build_generate_request(text, opts, model) do
    request = %{
      "type" => "generate",
      "text" => text
    }

    request =
      if audio_prompt = Keyword.get(opts, :audio_prompt) do
        Map.put(request, "audio_prompt", audio_prompt)
      else
        request
      end

    request =
      if model == :multilingual do
        language = Keyword.get(opts, :language, "en")
        Map.put(request, "language", language)
      else
        request
      end

    request =
      if model == :english do
        request
        |> maybe_put("exaggeration", Keyword.get(opts, :exaggeration))
        |> maybe_put("cfg_weight", Keyword.get(opts, :cfg_weight))
      else
        request
      end

    request
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp send_request(port, request) do
    json = Jason.encode!(request)
    Port.command(port, json <> "\n")
    :ok
  rescue
    ArgumentError -> {:error, :port_closed}
  end

  defp parse_response(data) do
    # Handle line-based output from port
    data = String.trim_trailing(data, "\n")

    case Jason.decode(data) do
      {:ok, response} -> {:ok, response, ""}
      {:error, _} -> :incomplete
    end
  end

  defp handle_response(%{"status" => "ok", "audio" => audio_base64}, state) do
    audio = Base.decode64!(audio_base64)

    if state.pending do
      GenServer.reply(state.pending, {:ok, audio})
    end

    {:noreply, %{state | pending: nil}}
  end

  defp handle_response(%{"status" => "error", "error" => error}, state) do
    if state.pending do
      GenServer.reply(state.pending, {:error, error})
    end

    {:noreply, %{state | pending: nil}}
  end

  defp handle_response(_response, state) do
    {:noreply, state}
  end
end
