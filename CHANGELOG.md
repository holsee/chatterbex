# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-12-26

### Added

- Initial release
- `Chatterbex.start_link/1` - Start a TTS server with model selection (`:turbo`, `:english`, `:multilingual`)
- `Chatterbex.generate/3` - Generate speech from text with optional voice cloning
- `Chatterbex.save/2` - Save generated audio to WAV file
- Support for three Chatterbox model variants:
  - **Turbo** (350M) - Low-latency English with paralinguistic tags (`[laugh]`, `[cough]`, etc.)
  - **English** (500M) - High-quality English with `exaggeration` and `cfg_weight` controls
  - **Multilingual** (500M) - 23+ languages via `language` parameter
- Zero-shot voice cloning via `audio_prompt` option
- Mix task `mix chatterbex.setup` for Python dependency installation
- Support for CPU, CUDA, and MPS (Apple Silicon) backends
- Erlang Port-based architecture for Python interoperability

[Unreleased]: https://github.com/holsee/chatterbex/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/holsee/chatterbex/releases/tag/v0.1.0
