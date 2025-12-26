# ADR-0006: Native Elixir Model Execution (Eliminating Python Dependency)

## Status

Proposed

## Date

2025-12-26

## Context

Chatterbex currently uses Erlang Ports to communicate with a Python process that runs the Chatterbox TTS models (see ADR-0001). While this approach works reliably, it introduces operational complexity:

1. **Python dependency**: Requires Python 3.10 or 3.11 (not 3.12+) with specific packages
2. **Startup latency**: Model loading takes 30-60 seconds through the Python bridge
3. **Deployment complexity**: Two runtimes (BEAM + Python) must be managed
4. **Resource overhead**: Separate process memory, JSON serialization, Base64 encoding

Since ADR-0001 was written, significant developments have occurred:

1. **ResembleAI released [Chatterbox-Turbo-ONNX](https://huggingface.co/ResembleAI/chatterbox-turbo-ONNX)** - Official ONNX exports of the Turbo model with multiple quantization options (fp32, fp16, q8, q4, q4f16)
2. **[Ortex](https://github.com/elixir-nx/ortex) has matured** - Production-ready ONNX Runtime bindings for Elixir with GPU support (CUDA, TensorRT, CoreML)
3. **The Nx ecosystem continues to evolve** - Better tooling for running neural networks natively in Elixir

This ADR evaluates options for running Chatterbox models natively in Elixir without Python.

## Decision

**Recommended approach: Use Ortex to run Chatterbox-Turbo-ONNX models natively.**

This approach leverages:
- Official ONNX models from ResembleAI (4 model files totaling ~350M parameters)
- Ortex for ONNX Runtime execution with hardware acceleration
- Nx tensors for seamless integration with the Elixir ecosystem

### Architecture

```text
┌─────────────────┐     Nx.Tensor      ┌─────────────────────┐
│  Chatterbex     │ ──────────────────▶│  Ortex              │
│  GenServer      │                    │  (ONNX Runtime)     │
│  (Elixir)       │ ◀───────────────── │                     │
└─────────────────┘   Nx.Tensor        └─────────────────────┘
                                              │
                                              ▼
                                       ┌─────────────────────┐
                                       │  ONNX Models        │
                                       │  - speech_encoder   │
                                       │  - embed_tokens     │
                                       │  - language_model   │
                                       │  - cond_decoder     │
                                       └─────────────────────┘
```

### Chatterbox-Turbo ONNX Model Components

| Component | Purpose |
|-----------|---------|
| `speech_encoder.onnx` | Extracts speaker embeddings from reference audio |
| `embed_tokens.onnx` | Converts text tokens to embeddings |
| `language_model.onnx` | Generates speech tokens autoregressively |
| `conditional_decoder.onnx` | Single-step mel-to-waveform synthesis |

### Implementation Approach

```elixir
defmodule Chatterbex.Native do
  @moduledoc "Native ONNX-based Chatterbox inference"

  def load_models(model_dir, opts \\ []) do
    # Load all 4 ONNX models
    {:ok, speech_encoder} = Ortex.load(Path.join(model_dir, "speech_encoder.onnx"))
    {:ok, embed_tokens} = Ortex.load(Path.join(model_dir, "embed_tokens.onnx"))
    {:ok, language_model} = Ortex.load(Path.join(model_dir, "language_model.onnx"))
    {:ok, cond_decoder} = Ortex.load(Path.join(model_dir, "conditional_decoder.onnx"))

    %{
      speech_encoder: speech_encoder,
      embed_tokens: embed_tokens,
      language_model: language_model,
      conditional_decoder: cond_decoder
    }
  end

  def generate(models, text, reference_audio, opts \\ []) do
    # 1. Encode reference audio to speaker embedding
    speaker_embedding = Ortex.run(models.speech_encoder, reference_audio)

    # 2. Tokenize and embed text
    tokens = tokenize(text)
    text_embeddings = Ortex.run(models.embed_tokens, tokens)

    # 3. Generate speech tokens autoregressively
    speech_tokens = generate_speech_tokens(models.language_model, text_embeddings, speaker_embedding, opts)

    # 4. Decode to waveform (single step in Turbo)
    waveform = Ortex.run(models.conditional_decoder, speech_tokens)

    {:ok, waveform}
  end
end
```

## Consequences

### Positive

- **No Python dependency**: Pure Elixir/BEAM deployment
- **Faster startup**: ONNX models load faster than PyTorch + model weights
- **Unified runtime**: Single runtime simplifies deployment, monitoring, and debugging
- **Better resource sharing**: Nx tensors integrate with BEAM memory management
- **Hardware flexibility**: ONNX Runtime supports CUDA, TensorRT, CoreML, DirectML
- **Quantization options**: Official q8/q4 models for reduced memory and faster inference
- **Nx ecosystem integration**: Works with Nx.Serving for concurrent inference

### Negative

- **Turbo model only**: ONNX exports only available for Turbo (350M), not English (500M) or Multilingual (500M)
- **No `exaggeration`/`cfg_weight` controls**: These parameters are specific to the English model
- **No multilingual support**: Would still need Python bridge for 23+ language support
- **Tokenizer complexity**: Need to port or wrap the text tokenization logic
- **Watermarking**: PerTh watermarker may need separate handling
- **New dependency**: Adds Ortex and ONNX Runtime (~100MB+ native libraries)

### Neutral

- May want to keep Python bridge as fallback for unsupported models
- Model files need to be downloaded from HuggingFace Hub
- Memory usage similar to Python approach (~1-2GB for model weights)

## Alternatives Considered

### 1. Bumblebee with Custom Model Port

**Status**: Not viable currently

Bumblebee does not support text-to-speech models. There is an [open feature request](https://github.com/elixir-nx/bumblebee/issues/209) for TTS support, but it remains unimplemented as of 2025.

Porting Chatterbox to Bumblebee would require:
- Implementing the model architecture in Axon
- Converting PyTorch weights to Axon format
- Implementing custom tokenization and audio processing

This represents months of work with uncertain compatibility.

### 2. Torchx Backend (Direct LibTorch)

**Status**: Theoretically possible, not practical

Nx's Torchx backend provides bindings to LibTorch (PyTorch's C++ core). However:
- Would need to load PyTorch model files (`.pt`/`.bin`), not ONNX
- More complex setup than ONNX Runtime
- Less mature than Ortex for inference workloads
- Still requires porting model architecture to Axon/Nx

### 3. AxonONNX (Convert ONNX to Axon)

**Status**: Potentially viable for simpler models

AxonONNX can convert some ONNX models to native Axon models. However:
- Complex models with custom operators may not convert cleanly
- Chatterbox uses specialized layers that may not be supported
- Would need testing to determine compatibility

### 4. HTTP Microservice (Keep Python, Different Protocol)

**Status**: Viable but doesn't eliminate Python

Could wrap Python in a FastAPI/Flask service. Compared to current Ports approach:
- Adds network overhead
- More deployment complexity
- Doesn't address the core issue (Python dependency)

### 5. Hybrid Approach

**Status**: Recommended for full feature support

Use Ortex for Turbo model (primary use case), keep Python bridge for:
- English model with `exaggeration`/`cfg_weight` controls
- Multilingual model for non-English languages
- Watermark detection (PerTh)

This provides the best of both worlds: native performance for the common case, full feature support when needed.

## Implementation Phases

### Phase 1: Core Ortex Integration
- Add Ortex dependency
- Implement model downloading from HuggingFace
- Basic text-to-speech generation with Turbo-ONNX

### Phase 2: Feature Parity
- Port tokenization logic to Elixir
- Implement voice cloning (reference audio processing)
- Support paralinguistic tags (`[laugh]`, `[cough]`, etc.)

### Phase 3: Production Hardening
- Nx.Serving for concurrent inference
- Quantized model support (q8, q4)
- GPU acceleration (CUDA, CoreML)
- Graceful fallback to Python bridge

## References

- [Chatterbox-Turbo-ONNX on HuggingFace](https://huggingface.co/ResembleAI/chatterbox-turbo-ONNX)
- [Ortex - ONNX Runtime bindings for Elixir](https://github.com/elixir-nx/ortex)
- [Elixir ML: Using Pre-trained ONNX Models with Ortex](https://dockyard.com/blog/2024/03/19/elixir-machine-learning-pre-trained-onnx-models-with-ortex)
- [Bumblebee TTS Feature Request](https://github.com/elixir-nx/bumblebee/issues/209)
- [Numerical Elixir (Nx) Organization](https://github.com/elixir-nx)
- [Three Years of Nx: Growing the Elixir ML Ecosystem](https://dockyard.com/blog/2023/11/08/three-years-of-nx-growing-the-machine-learning-ecosystem)
- [Catching Up: Where are Nx, Axon, and Bumblebee Headed?](https://dockyard.com/blog/2024/08/20/where-are-nx-axon-bumblebee-headed)
