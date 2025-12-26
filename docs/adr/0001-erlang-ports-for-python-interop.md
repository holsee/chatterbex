# ADR-0001: Use Erlang Ports for Python Interoperability

## Status

Accepted

## Date

2024-12-25

## Context

Chatterbex needs to integrate with Chatterbox TTS, a Python library for text-to-speech synthesis. The Chatterbox library provides no REST API or other language bindings—it is purely a Python library that loads ML models and generates audio.

We need a mechanism to call Python code from Elixir that:

1. Allows loading and persisting ML models in memory (models are 350MB-500MB)
2. Handles potentially long-running inference operations
3. Isolates Python process crashes from the BEAM
4. Supports bidirectional communication for requests and responses

## Decision

Use Erlang Ports to spawn and communicate with a long-running Python process.

The architecture:
- Each `Chatterbex.Server` GenServer owns one Port to a Python process
- The Python process loads the Chatterbox model on initialization
- Communication happens via stdin/stdout with JSON messages
- The Port is opened with `:exit_status` to detect Python crashes

```text
+---------------+      stdin (JSON)      +------------------+
|    Elixir     | ---------------------> |      Python      |
|   GenServer   |                        |  chatterbex_     |
|               | <--------------------- |  bridge.py       |
+---------------+      stdout (JSON)     +------------------+
```

## Consequences

### Positive

- **Process isolation**: Python crashes don't bring down the BEAM VM
- **Model persistence**: ML models stay loaded in Python process memory between requests
- **Simplicity**: Ports are a well-understood, battle-tested BEAM primitive
- **No external dependencies**: No need for NIFs, C extensions, or HTTP servers
- **Supervision compatibility**: Port processes can be supervised and restarted

### Negative

- **Serialization overhead**: All data must be serialized (JSON) between processes
- **No shared memory**: Large audio data must be copied between processes
- **Python dependency**: Requires Python 3.10+ installed on the system
- **Startup latency**: Model loading happens at process start (can take 30-60s)

### Neutral

- One Python process per model instance (intentional for isolation)
- Debug/logging requires coordination between Elixir and Python

## Alternatives Considered

### NIFs (Native Implemented Functions)

- **Rejected**: NIFs run in the BEAM scheduler; long-running ML inference would block schedulers and risk crashing the entire VM on segfaults.

### Dirty NIFs

- **Rejected**: Still shares memory with BEAM, Python GIL complications, complex to implement and debug.

### erlport / Pythonx

- **Rejected**: Additional dependencies for functionality we can achieve with standard Ports. These libraries add complexity without significant benefit for our use case.

### HTTP Server (Flask/FastAPI wrapper)

- **Rejected**: Adds network overhead, requires managing a separate server process, more complex deployment. Ports provide direct IPC without network stack.

### Nx/Bumblebee (Pure Elixir ML)

- **Rejected**: Chatterbox models are not available in ONNX or other formats supported by Nx. Would require significant porting effort with no guarantee of compatibility.

## References

- [Erlang Ports Documentation](https://www.erlang.org/doc/tutorial/c_port.html)
- [Elixir Port Module](https://hexdocs.pm/elixir/Port.html)
- [Chatterbox TTS Repository](https://github.com/resemble-ai/chatterbox)
