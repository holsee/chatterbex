# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Chatterbex is an Elixir wrapper for [Chatterbox TTS](https://github.com/resemble-ai/chatterbox) - a Python text-to-speech library with zero-shot voice cloning. It uses Erlang Ports to communicate with a long-running Python process.

## Build & Test Commands

```bash
# Install dependencies
mix deps.get

# Install Python dependencies (pick one)
mix chatterbex.setup --cpu     # CPU-only
mix chatterbex.setup --cuda    # CUDA-enabled

# Run tests
mix test

# Run a single test file
mix test test/chatterbex_test.exs

# Run a specific test by line number
mix test test/chatterbex_test.exs:5

# Generate docs
mix docs

# Format code
mix format
```

## Architecture

```
┌─────────────────┐     JSON/stdin      ┌─────────────────────┐
│  Chatterbex     │ ──────────────────▶ │  chatterbex_bridge  │
│  GenServer      │                     │  (Python process)   │
│  (Elixir)       │ ◀────────────────── │  Chatterbox TTS     │
└─────────────────┘   Base64 WAV/stdout └─────────────────────┘
```

### Key Components

- **`Chatterbex`** (`lib/chatterbex.ex`) - Public API module. Delegates to `Chatterbex.Server`.
- **`Chatterbex.Server`** (`lib/chatterbex/server.ex`) - GenServer that owns an Erlang Port to a Python process. Each instance loads one model (turbo/english/multilingual).
- **`chatterbex_bridge.py`** (`priv/python/chatterbex_bridge.py`) - Python script that loads Chatterbox models and handles JSON requests via stdin/stdout.
- **`Mix.Tasks.Chatterbex.Setup`** (`lib/mix/tasks/chatterbex.setup.ex`) - Mix task for Python dependency installation.

### IPC Protocol

Communication uses newline-delimited JSON:
- Requests: `{"type": "init"|"generate", ...}`
- Responses: `{"status": "ok"|"error", "audio": "<base64>", "error": "<message>"}`

Audio data is Base64-encoded for JSON transport.

### Model Variants

- **Turbo** (350M) - Low-latency English, supports paralinguistic tags like `[laugh]`
- **English** (500M) - High-quality English with `exaggeration` and `cfg_weight` controls
- **Multilingual** (500M) - 23+ languages via `language` parameter

## Python Requirements

- Python 3.10 or 3.11 required (3.12+ not supported due to numpy compatibility)
- `chatterbox-tts` package plus PyTorch
- Model loading takes 30-60 seconds on first start (downloads ~1-2GB weights)

## ADR Documentation

Architectural decisions are documented in `docs/adr/`:
- ADR-0001: Erlang Ports for Python interop
- ADR-0002: GenServer per model instance
- ADR-0003: JSON with Base64 for IPC protocol
- ADR-0004: Mix task for Python setup
