defmodule Mix.Tasks.Chatterbex.Setup do
  @moduledoc """
  Installs Python dependencies required for Chatterbex.

  ## Requirements

  **Python 3.10 or 3.11 is required.** Python 3.12+ is not supported due to
  numpy compatibility issues with the chatterbox-tts package.

  ## Usage

      mix chatterbex.setup --cpu
      mix chatterbex.setup --cuda
      mix chatterbex.setup --mps

  ## Options

    * `--cpu` - Install CPU-only version of PyTorch (smaller download, no GPU required)
    * `--cuda` - Install CUDA-enabled version of PyTorch (requires NVIDIA GPU)
    * `--mps` - Install PyTorch with MPS support for Apple Silicon (M1/M2/M3/M4 Macs)
    * `--venv PATH` - Create and use a virtual environment at PATH
    * `--pip PATH` - Use a specific pip executable

  ## Examples

      # CPU-only (no CUDA required)
      mix chatterbex.setup --cpu

      # CUDA-enabled (requires NVIDIA GPU)
      mix chatterbex.setup --cuda

      # Apple Silicon with MPS acceleration
      mix chatterbex.setup --mps

      # Use a virtual environment with MPS
      mix chatterbex.setup --mps --venv .venv

  """

  use Mix.Task

  @shortdoc "Installs Python dependencies for Chatterbex"

  @requirements ["app.config"]

  @switches [
    cpu: :boolean,
    cuda: :boolean,
    mps: :boolean,
    venv: :string,
    pip: :string
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    with :ok <- validate_compute_option(opts) do
      run_setup(opts)
    else
      {:error, message} ->
        Mix.shell().error(message)
        exit({:shutdown, 1})
    end
  end

  defp validate_compute_option(opts) do
    selected = Enum.filter([:cpu, :cuda, :mps], &opts[&1])

    case selected do
      [] ->
        {:error,
         """
         Must specify a compute option:

           mix chatterbex.setup --cpu   # CPU-only
           mix chatterbex.setup --cuda  # CUDA-enabled (NVIDIA GPU)
           mix chatterbex.setup --mps   # Apple Silicon (M1/M2/M3/M4)
         """}

      [_] ->
        :ok

      _ ->
        {:error, "Cannot specify multiple compute options (--cpu, --cuda, --mps)"}
    end
  end

  defp run_setup(opts) do
    compute =
      cond do
        opts[:cuda] -> "CUDA"
        opts[:mps] -> "MPS (Apple Silicon)"
        true -> "CPU"
      end

    Mix.shell().info("Setting up Chatterbex Python dependencies (#{compute})...")

    pip = determine_pip(opts)

    with :ok <- maybe_create_venv(opts),
         :ok <- check_python_version(opts),
         :ok <- install_dependencies(pip, opts) do
      Mix.shell().info([:green, "Chatterbex setup complete!"])
      print_usage_instructions()
    else
      {:error, message} ->
        Mix.shell().error(message)
        exit({:shutdown, 1})
    end
  end

  defp determine_pip(opts) do
    cond do
      pip = opts[:pip] ->
        pip

      venv = opts[:venv] ->
        Path.join([venv, "bin", "pip"])

      true ->
        System.find_executable("pip3") || System.find_executable("pip") || "pip"
    end
  end

  defp maybe_create_venv(opts) do
    case opts[:venv] do
      nil ->
        :ok

      venv_path ->
        if File.exists?(venv_path) do
          Mix.shell().info("Using existing virtual environment at #{venv_path}")
          :ok
        else
          Mix.shell().info("Creating virtual environment at #{venv_path}...")
          python = System.find_executable("python3") || System.find_executable("python")

          case System.cmd(python, ["-m", "venv", venv_path], stderr_to_stdout: true) do
            {_, 0} ->
              Mix.shell().info([:green, "Virtual environment created"])
              :ok

            {output, _} ->
              {:error, "Failed to create virtual environment: #{output}"}
          end
        end
    end
  end

  defp check_python_version(opts) do
    python =
      case opts[:venv] do
        nil -> System.find_executable("python3") || System.find_executable("python")
        venv -> Path.join([venv, "bin", "python"])
      end

    case System.cmd(python, ["--version"], stderr_to_stdout: true) do
      {version_output, 0} ->
        version = String.trim(version_output)
        Mix.shell().info("Found #{version}")

        if version_supported?(version) do
          :ok
        else
          {:error,
           "Python 3.10 or 3.11 is required (3.12+ is not supported due to numpy compatibility issues with chatterbox-tts). Found: #{version}"}
        end

      {_, _} ->
        {:error, "Python not found. Please install Python 3.10+"}
    end
  end

  defp version_supported?(version_string) do
    case Regex.run(~r/Python (\d+)\.(\d+)/, version_string) do
      [_, major, minor] ->
        {major, _} = Integer.parse(major)
        {minor, _} = Integer.parse(minor)
        # Python 3.10 or 3.11 only - Python 3.12+ breaks numpy <1.26 which chatterbox-tts requires
        major == 3 and minor in [10, 11]

      _ ->
        false
    end
  end

  defp install_dependencies(pip, opts) do
    packages = build_package_list(opts)

    Enum.reduce_while(packages, :ok, fn {name, install_args}, :ok ->
      Mix.shell().info("Installing #{name}...")

      case System.cmd(pip, ["install" | install_args], stderr_to_stdout: true) do
        {_, 0} ->
          Mix.shell().info([:green, "  #{name} installed"])
          {:cont, :ok}

        {output, _} ->
          {:halt, {:error, "Failed to install #{name}: #{output}"}}
      end
    end)
  end

  defp build_package_list(opts) do
    base_packages = [
      {"chatterbox-tts", ["chatterbox-tts"]}
    ]

    cond do
      opts[:cpu] ->
        # CPU-only: install PyTorch CPU version first
        cpu_torch =
          {"torch (CPU)",
           ["torch", "torchaudio", "--index-url", "https://download.pytorch.org/whl/cpu"]}

        [cpu_torch | base_packages]

      opts[:cuda] ->
        # CUDA: install PyTorch with CUDA support first
        cuda_torch = {"torch (CUDA)", ["torch", "torchaudio"]}
        [cuda_torch | base_packages]

      opts[:mps] ->
        # MPS (Apple Silicon): install default PyTorch which includes MPS support on macOS
        # PyTorch 2.0+ automatically supports MPS on Apple Silicon
        mps_torch = {"torch (MPS)", ["torch", "torchaudio"]}
        [mps_torch | base_packages]
    end
  end

  defp print_usage_instructions do
    Mix.shell().info("""

    You can now use Chatterbex in your application:

        {:ok, pid} = Chatterbex.start_link(model: :turbo)
        {:ok, audio} = Chatterbex.generate(pid, "Hello, world!")
        :ok = Chatterbex.save(audio, "output.wav")

    Note: First run will download model weights (~1-2 GB).
    """)
  end
end
