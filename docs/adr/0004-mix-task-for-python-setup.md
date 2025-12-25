# ADR-0004: Mix Task for Python Dependency Setup

## Status

Accepted

## Date

2024-12-25

## Context

Chatterbex requires Python dependencies that are outside the Elixir/Hex ecosystem:

- `chatterbox-tts` - The core TTS library
- `torch` / `torchaudio` - PyTorch for ML inference
- Various transitive dependencies

Users need to install these before using Chatterbex. The installation varies based on:

1. **Compute target**: CUDA (GPU) vs CPU-only
2. **Environment**: System Python vs virtual environment
3. **Platform**: Different PyTorch wheels for different platforms

We want to provide a smooth onboarding experience while respecting that Python environment management is complex and users may have existing setups.

## Decision

Provide a Mix task (`mix chatterbex.setup`) that automates Python dependency installation with explicit compute target selection.

```bash
# CPU-only installation
mix chatterbex.setup --cpu

# CUDA-enabled installation
mix chatterbex.setup --cuda

# With virtual environment
mix chatterbex.setup --cpu --venv .venv
```

Key design choices:

1. **Require explicit --cpu or --cuda**: No default—users must consciously choose their compute target
2. **Optional venv creation**: `--venv PATH` creates and uses a virtual environment
3. **Custom pip support**: `--pip PATH` for non-standard Python setups
4. **Validation**: Check Python version (3.10+) before installing
5. **Clear output**: Show progress and final usage instructions

## Consequences

### Positive

- **Discoverability**: `mix help chatterbex.setup` documents all options
- **Reproducibility**: Explicit flags make installations consistent
- **Flexibility**: Supports venv, custom pip, CPU/CUDA variants
- **User guidance**: Error messages guide users to correct usage
- **Idiomatic**: Mix tasks are the standard Elixir way to provide CLI tools

### Negative

- **Not a full Python environment manager**: Users with complex Python setups may still prefer manual installation
- **Platform assumptions**: Assumes `pip` and `python3` are in PATH
- **No lockfile**: Doesn't pin exact Python package versions (relies on pip resolution)

### Neutral

- Manual installation remains an option (documented in README)
- Task is optional—library works without running it if deps are installed

## Alternatives Considered

### No Setup Automation

Just document `pip install chatterbox-tts` in README.

- **Rejected**: Poor developer experience. CUDA vs CPU PyTorch selection is a common pain point that we can solve.

### Docker-based Setup

Provide a Dockerfile with all dependencies.

- **Rejected**: Too heavy for a library. Docker is orthogonal to Elixir dependency management. Users can create their own Docker setup if needed.

### Bundled Python (PyInstaller/PyOxidizer)

Ship a self-contained Python executable.

- **Rejected**: Massive binary size (GB+), complex to build and maintain, CUDA compatibility issues.

### Automatic Detection of CUDA

Detect GPU presence and auto-select CUDA.

- **Rejected**: Error-prone (CUDA toolkit version mismatches), surprising behavior. Explicit is better than implicit for compute target selection.

### Runtime Installation Check

Check and install dependencies on first `Chatterbex.start_link/1`.

- **Rejected**: Installation during runtime is surprising and slow. Setup should be an explicit step.

## References

- [Mix.Task Documentation](https://hexdocs.pm/mix/Mix.Task.html)
- [PyTorch Installation Matrix](https://pytorch.org/get-started/locally/)
- [Python venv Module](https://docs.python.org/3/library/venv.html)
