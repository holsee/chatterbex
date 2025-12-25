#!/usr/bin/env python3
"""
Chatterbex Bridge - Python bridge for Elixir Chatterbex library.

This script communicates with the Elixir GenServer via stdin/stdout,
loading and running Chatterbox TTS models.
"""

import sys
import json
import base64
import io

# Attempt to import torch and torchaudio early to catch missing deps
try:
    import torch
    import torchaudio as ta
except ImportError as e:
    print(json.dumps({"status": "error", "error": f"Missing dependency: {e}"}))
    sys.exit(1)


class ChatterboxBridge:
    """Bridge between Elixir and Chatterbox TTS models."""

    def __init__(self):
        self.model = None
        self.model_type = None
        self.device = None

    def init_model(self, model_type: str, device: str = "cuda") -> dict:
        """Initialize the specified Chatterbox model."""
        try:
            self.device = device
            self.model_type = model_type

            if model_type == "turbo":
                from chatterbox.tts_turbo import ChatterboxTurboTTS
                self.model = ChatterboxTurboTTS.from_pretrained(device=device)

            elif model_type == "english":
                from chatterbox.tts import ChatterboxTTS
                self.model = ChatterboxTTS.from_pretrained(device=device)

            elif model_type == "multilingual":
                from chatterbox.mtl_tts import ChatterboxMultilingualTTS
                self.model = ChatterboxMultilingualTTS.from_pretrained(device=device)

            else:
                return {"status": "error", "error": f"Unknown model type: {model_type}"}

            return {"status": "ok"}

        except Exception as e:
            return {"status": "error", "error": str(e)}

    def generate(self, text: str, **kwargs) -> dict:
        """Generate speech from text."""
        if self.model is None:
            return {"status": "error", "error": "Model not initialized"}

        try:
            # Build generation arguments
            gen_kwargs = {}

            if "audio_prompt" in kwargs and kwargs["audio_prompt"]:
                gen_kwargs["audio_prompt_path"] = kwargs["audio_prompt"]

            if self.model_type == "multilingual" and "language" in kwargs:
                gen_kwargs["language_id"] = kwargs["language"]

            if self.model_type == "english":
                if "exaggeration" in kwargs and kwargs["exaggeration"] is not None:
                    gen_kwargs["exaggeration"] = kwargs["exaggeration"]
                if "cfg_weight" in kwargs and kwargs["cfg_weight"] is not None:
                    gen_kwargs["cfg_weight"] = kwargs["cfg_weight"]

            # Generate audio
            wav = self.model.generate(text, **gen_kwargs)

            # Convert to WAV bytes
            audio_bytes = self._wav_to_bytes(wav, self.model.sr)

            # Encode as base64 for JSON transport
            audio_base64 = base64.b64encode(audio_bytes).decode("utf-8")

            return {"status": "ok", "audio": audio_base64}

        except Exception as e:
            return {"status": "error", "error": str(e)}

    def _wav_to_bytes(self, wav: torch.Tensor, sample_rate: int) -> bytes:
        """Convert a PyTorch tensor to WAV bytes."""
        buffer = io.BytesIO()

        # Ensure correct shape (channels, samples)
        if wav.dim() == 1:
            wav = wav.unsqueeze(0)

        ta.save(buffer, wav.cpu(), sample_rate, format="wav")
        buffer.seek(0)
        return buffer.read()


def main():
    """Main loop - read JSON commands from stdin, write responses to stdout."""
    bridge = ChatterboxBridge()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            request = json.loads(line)
        except json.JSONDecodeError as e:
            response = {"status": "error", "error": f"Invalid JSON: {e}"}
            print(json.dumps(response), flush=True)
            continue

        request_type = request.get("type")

        if request_type == "init":
            model_type = request.get("model", "turbo")
            device = request.get("device", "cuda")
            response = bridge.init_model(model_type, device)

        elif request_type == "generate":
            text = request.get("text", "")
            kwargs = {
                k: v for k, v in request.items()
                if k not in ("type", "text")
            }
            response = bridge.generate(text, **kwargs)

        elif request_type == "ping":
            response = {"status": "ok", "message": "pong"}

        else:
            response = {"status": "error", "error": f"Unknown request type: {request_type}"}

        print(json.dumps(response), flush=True)


if __name__ == "__main__":
    main()
