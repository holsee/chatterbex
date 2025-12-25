# Chatterbex Examples

Example scripts demonstrating Chatterbex text-to-speech capabilities.

## Prerequisites

Before running examples, install Python dependencies:

```bash
# Choose one based on your hardware:
mix chatterbex.setup --cpu     # CPU-only
mix chatterbex.setup --cuda    # NVIDIA GPU
mix chatterbex.setup --mps     # Apple Silicon (M1/M2/M3/M4)
```

## Examples

### Hello World

Basic text-to-speech generation:

```bash
# Default usage
mix run examples/hello_world.exs

# Custom text
mix run examples/hello_world.exs --text "Welcome to Chatterbex!"

# Specify output file
mix run examples/hello_world.exs --text "Hello!" --output greeting.wav

# Use Apple Silicon GPU
mix run examples/hello_world.exs --device mps

# Use different model
mix run examples/hello_world.exs --model english
```

**Options:**
- `--text` - Text to synthesize (default: "Hello, world! This is Chatterbex speaking.")
- `--output` - Output WAV file path (default: hello_world.wav)
- `--device` - Compute device: `cpu`, `cuda`, `mps` (default: cpu)
- `--model` - Model variant: `turbo`, `english`, `multilingual` (default: turbo)

### Voice Cloning

Clone a voice from a reference audio sample:

```bash
# Basic voice cloning
mix run examples/voice_cloning.exs --reference path/to/voice.wav

# Custom text with cloned voice
mix run examples/voice_cloning.exs --reference voice.wav --text "I sound like you now!"

# Adjust voice exaggeration
mix run examples/voice_cloning.exs --reference voice.wav --exaggeration 0.7
```

**Options:**
- `--reference` - Path to reference audio file (required, 6-10 seconds recommended)
- `--text` - Text to synthesize with cloned voice
- `--output` - Output WAV file path (default: cloned_voice.wav)
- `--device` - Compute device: `cpu`, `cuda`, `mps` (default: cpu)
- `--exaggeration` - Voice exaggeration factor 0.0-1.0 (default: 0.5)

**Tips for voice cloning:**
- Use 6-10 seconds of clear speech as reference
- WAV format works best
- Minimize background noise in reference audio
- Higher exaggeration = more expressive output

### Multilingual

Text-to-speech in 23+ languages:

```bash
# French
mix run examples/multilingual.exs --text "Bonjour le monde!" --language fr

# German
mix run examples/multilingual.exs --text "Guten Tag" --language de

# Japanese
mix run examples/multilingual.exs --text "こんにちは" --language ja

# List all supported languages
mix run examples/multilingual.exs --list-languages
```

**Options:**
- `--text` / `-t` - Text to synthesize (default: sample text in selected language)
- `--language` / `-l` - Language code (default: en)
- `--output` / `-o` - Output WAV file path (default: multilingual_<lang>.wav)
- `--device` - Compute device: `cpu`, `cuda`, `mps` (default: cpu)
- `--list-languages` - Print supported languages and exit

**Supported languages:**
en, fr, de, es, it, pt, nl, pl, ru, uk, cs, sk, hu, ro, bg, hr, sl, sr, mk, sq, tr, ar, he, zh, ja, ko, vi, th, id, ms

## Model Variants

| Model | Parameters | Use Case |
|-------|------------|----------|
| `turbo` | 350M | Low-latency English, supports `[laugh]`, `[sigh]` tags |
| `english` | 500M | High-quality English with voice control parameters |
| `multilingual` | 500M | 23+ languages with zero-shot voice cloning |

## Performance Notes

- First run downloads model weights (~1-2 GB)
- Model loading takes 30-60 seconds
- Use `--device mps` on Apple Silicon for 2-3x speedup
- Use `--device cuda` on NVIDIA GPUs for best performance
