# ADR-0005: Apple Silicon MPS Support

## Status

Accepted

## Date

2025-12-25

## Context

Apple Silicon Macs (M1/M2/M3/M4) have become increasingly popular for ML development. These chips include powerful GPU cores that can accelerate PyTorch workloads through Metal Performance Shaders (MPS). However, the Chatterbox TTS library was primarily developed for CUDA-based systems and has compatibility issues with MPS:

1. Model checkpoints are saved with CUDA tensor references
2. Some operations have MPS-specific tensor allocation issues ("Placeholder storage has not been allocated on MPS device")
3. Direct MPS loading can fail, requiring a CPU-first loading strategy

Users on Apple Silicon were limited to CPU-only inference, which is significantly slower than GPU-accelerated inference.

## Decision

Add MPS device support to Chatterbex with the following implementation strategy:

1. **torch.load monkey patch**: Patch `torch.load` to default to CPU map_location, ensuring CUDA-saved models can be loaded on non-CUDA systems.

2. **CPU-first loading for MPS**: When MPS is requested, first load the model to CPU, then move individual model components to MPS. This avoids MPS placeholder allocation errors.

3. **Graceful fallback**: If MPS initialization fails for any component, automatically fall back to CPU mode for stability.

4. **New setup flag**: Add `--mps` flag to `mix chatterbex.setup` for installing PyTorch with MPS support.

5. **Device detection**: Add `_detect_device()` function that validates requested devices and handles fallback logic.

## Consequences

### Positive

- Apple Silicon users can leverage GPU acceleration (2-3x faster inference)
- Automatic fallback ensures stability even if MPS has issues
- Consistent API across all platforms (just change `device: "mps"`)
- No changes required to existing CUDA or CPU workflows

### Negative

- MPS support in Chatterbox is experimental and may have edge cases
- Additional complexity in Python bridge for device handling
- Performance may not match CUDA on equivalent-tier NVIDIA GPUs

### Neutral

- Model loading is slightly slower on MPS (CPU load + move to MPS)
- Documentation needs to reflect new platform support

## Alternatives Considered

### 1. Wait for upstream Chatterbox MPS support

Rejected because the upstream library may not prioritize MPS support, and users need a solution now.

### 2. Force CPU-only on macOS

Rejected because this would leave significant performance on the table for Apple Silicon users.

### 3. Use MLX (Apple's ML framework) instead of PyTorch

Rejected because it would require rewriting the model loading logic and Chatterbox is built on PyTorch.

## References

- [Chatterbox TTS Apple Silicon Space](https://huggingface.co/spaces/Jimmi42/chatterbox-tts-apple-silicon)
- [PyTorch MPS Backend Documentation](https://pytorch.org/docs/stable/notes/mps.html)
- [Metal Performance Shaders](https://developer.apple.com/documentation/metalperformanceshaders)
