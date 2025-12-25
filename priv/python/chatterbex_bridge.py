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

# Monkey patch torch.load to handle CUDA->CPU/MPS device mapping
# This is needed because Chatterbox models are saved with CUDA references
_original_torch_load = torch.load


def _patched_torch_load(f, map_location=None, **kwargs):
    """Patched torch.load that maps CUDA tensors to CPU for compatibility."""
    if map_location is None:
        map_location = "cpu"
    return _original_torch_load(f, map_location=map_location, **kwargs)


torch.load = _patched_torch_load


def _detect_device(requested_device: str) -> str:
    """
    Detect and validate the compute device.

    Returns the best available device, with fallback handling for MPS.
    """
    if requested_device == "cuda":
        if torch.cuda.is_available():
            return "cuda"
        return "cpu"
    elif requested_device == "mps":
        if torch.backends.mps.is_available():
            return "mps"
        return "cpu"
    else:
        return "cpu"


class ChatterboxBridge:
    """Bridge between Elixir and Chatterbox TTS models."""

    def __init__(self):
        self.model = None
        self.model_type = None
        self.device = None

    def init_model(self, model_type: str, device: str = "cuda") -> dict:
        """Initialize the specified Chatterbox model."""
        try:
            # Validate and detect actual device
            actual_device = _detect_device(device)
            self.device = actual_device
            self.model_type = model_type

            # For MPS, load to CPU first then move components
            # This avoids "Placeholder storage has not been allocated on MPS device" errors
            load_device = "cpu" if actual_device == "mps" else actual_device

            if model_type == "turbo":
                from chatterbox.tts_turbo import ChatterboxTurboTTS
                self.model = ChatterboxTurboTTS.from_pretrained(device=load_device)

            elif model_type == "english":
                from chatterbox.tts import ChatterboxTTS
                self.model = ChatterboxTTS.from_pretrained(device=load_device)

            elif model_type == "multilingual":
                from chatterbox.mtl_tts import ChatterboxMultilingualTTS
                self.model = ChatterboxMultilingualTTS.from_pretrained(device=load_device)

            else:
                return {"status": "error", "error": f"Unknown model type: {model_type}"}

            # Move model components to MPS if requested
            if actual_device == "mps" and load_device == "cpu":
                self._move_to_mps()

            return {"status": "ok", "device": actual_device}

        except Exception as e:
            return {"status": "error", "error": str(e)}

    def _move_to_mps(self) -> None:
        """
        Move model components to MPS device.

        Chatterbox models have multiple subcomponents that need to be moved individually.
        If MPS fails for any component, fall back to CPU for stability.
        """
        try:
            # Common components across model types
            for component_name in ["t3", "s3gen", "ve", "model"]:
                if hasattr(self.model, component_name):
                    component = getattr(self.model, component_name)
                    if component is not None and hasattr(component, "to"):
                        setattr(self.model, component_name, component.to("mps"))

            # Update model's device reference if it has one
            if hasattr(self.model, "device"):
                self.model.device = "mps"

        except Exception:
            # MPS failed, fall back to CPU
            self.device = "cpu"
            if hasattr(self.model, "device"):
                self.model.device = "cpu"

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
