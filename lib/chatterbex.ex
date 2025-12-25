defmodule Chatterbex do
  @moduledoc """
  Elixir wrapper for Chatterbox TTS - state-of-the-art text-to-speech models.

  Chatterbox provides three model variants:

  - **Turbo** (350M params) - Low-latency, English only, supports paralinguistic tags
  - **English** (500M params) - High-quality English TTS with CFG controls
  - **Multilingual** (500M params) - Supports 23+ languages with zero-shot voice cloning

  ## Quick Start

      # Start a model server
      {:ok, pid} = Chatterbex.start_link(model: :turbo)

      # Generate speech
      {:ok, audio} = Chatterbex.generate(pid, "Hello, world!")

      # Save to file
      :ok = Chatterbex.save(audio, "output.wav")

  ## Voice Cloning

      {:ok, audio} = Chatterbex.generate(pid, "Hello!",
        audio_prompt: "path/to/reference.wav"
      )

  ## Multilingual

      {:ok, pid} = Chatterbex.start_link(model: :multilingual)
      {:ok, audio} = Chatterbex.generate(pid, "Bonjour!", language: "fr")

  """

  alias Chatterbex.Server

  @type model :: :turbo | :english | :multilingual
  @type audio :: binary()
  @type generate_opts :: [
          audio_prompt: String.t(),
          language: String.t(),
          exaggeration: float(),
          cfg_weight: float()
        ]

  @doc """
  Starts a Chatterbex model server.

  ## Options

    * `:model` - The model variant to use (`:turbo`, `:english`, `:multilingual`). Default: `:turbo`
    * `:device` - The device to use (`"cuda"`, `"cpu"`). Default: `"cuda"`
    * `:name` - Optional name for the GenServer

  ## Examples

      {:ok, pid} = Chatterbex.start_link(model: :turbo)
      {:ok, pid} = Chatterbex.start_link(model: :multilingual, device: "cpu")

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    Server.start_link(opts)
  end

  @doc """
  Generates speech audio from text.

  ## Options

    * `:audio_prompt` - Path to a reference audio file for voice cloning (10 seconds recommended)
    * `:language` - Language code for multilingual model (e.g., "fr", "de", "zh")
    * `:exaggeration` - Exaggeration factor for English model (0.0 to 1.0)
    * `:cfg_weight` - CFG weight for English model

  ## Examples

      {:ok, audio} = Chatterbex.generate(pid, "Hello, world!")

      {:ok, audio} = Chatterbex.generate(pid, "Hi there [laugh]",
        audio_prompt: "voice_sample.wav"
      )

  """
  @spec generate(GenServer.server(), String.t(), generate_opts()) ::
          {:ok, audio()} | {:error, term()}
  def generate(server, text, opts \\ []) do
    Server.generate(server, text, opts)
  end

  @doc """
  Generates speech audio synchronously with a timeout.

  Same as `generate/3` but allows specifying a timeout.
  """
  @spec generate(GenServer.server(), String.t(), generate_opts(), timeout()) ::
          {:ok, audio()} | {:error, term()}
  def generate(server, text, opts, timeout) do
    Server.generate(server, text, opts, timeout)
  end

  @doc """
  Saves audio binary to a WAV file.

  ## Examples

      {:ok, audio} = Chatterbex.generate(pid, "Hello!")
      :ok = Chatterbex.save(audio, "output.wav")

  """
  @spec save(audio(), Path.t()) :: :ok | {:error, term()}
  def save(audio, path) when is_binary(audio) do
    File.write(path, audio)
  end

  @doc """
  Returns the sample rate for the given model.

  All Chatterbox models use 24kHz sample rate.
  """
  @spec sample_rate(model()) :: pos_integer()
  def sample_rate(_model), do: 24_000

  @doc """
  Stops a running model server.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(server) do
    Server.stop(server)
  end

  @doc """
  Lists supported languages for the multilingual model.
  """
  @spec supported_languages() :: [String.t()]
  def supported_languages do
    ~w(en fr de es it pt nl pl ru uk cs sk hu ro bg hr sl sr mk sq
       tr ar he zh ja ko vi th id ms)
  end

  @doc """
  Returns the list of supported paralinguistic tags for the Turbo model.

  These can be embedded in text like: "Hello [laugh] how are you?"
  """
  @spec paralinguistic_tags() :: [String.t()]
  def paralinguistic_tags do
    ~w([laugh] [chuckle] [cough] [sigh] [gasp] [groan] [yawn] [sniff] [clearing_throat])
  end
end
