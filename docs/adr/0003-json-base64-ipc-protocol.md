# ADR-0003: JSON with Base64 for IPC Protocol

## Status

Accepted

## Date

2024-12-25

## Context

Communication between Elixir (GenServer) and Python (chatterbex_bridge.py) requires a serialization protocol. The protocol must handle:

1. **Requests**: Text input, optional file paths, model parameters
2. **Responses**: Status, error messages, and binary audio data (WAV files)

Key constraints:
- Erlang Ports use stdin/stdout as byte streams
- Audio data is binary (WAV format, can be several MB)
- Need clear message boundaries
- Should be debuggable (human-readable preferred)

## Decision

Use JSON for message serialization with Base64 encoding for binary audio data. Messages are newline-delimited (one JSON object per line).

### Request Format

```json
{"type": "init", "model": "turbo", "device": "cuda"}
{"type": "generate", "text": "Hello world", "audio_prompt": "/path/to/ref.wav"}
```

### Response Format

```json
{"status": "ok"}
{"status": "ok", "audio": "UklGRi4AAABXQVZFZm10IBAAAA..."}
{"status": "error", "error": "Model not initialized"}
```

### Protocol Details

- **Delimiter**: Newline (`\n`) separates messages
- **Encoding**: UTF-8 for JSON, Base64 for binary audio
- **Line buffering**: Port opened with `{:line, 1_000_000}` for line-based reading
- **Flush**: Python uses `flush=True` on print to ensure immediate delivery

## Consequences

### Positive

- **Debuggable**: JSON is human-readable; can log and inspect messages
- **Language agnostic**: JSON supported everywhere; easy to test Python bridge independently
- **Simple parsing**: Both Elixir (Jason) and Python (json) have robust JSON support
- **Safe binary transport**: Base64 avoids any encoding issues with binary data
- **No external dependencies**: No need for protobuf, msgpack, or other serialization libraries

### Negative

- **Base64 overhead**: ~33% size increase for audio data
- **Serialization cost**: JSON parsing has CPU overhead vs binary protocols
- **Memory**: Full audio must be buffered in memory for Base64 encoding/decoding
- **No streaming**: Current design waits for complete audio before responding

### Neutral

- Line length limit (1MB) sufficient for typical audio responses
- Error messages are strings (no structured error codes)

## Alternatives Considered

### Protocol Buffers / MessagePack

Binary serialization formats with schemas.

- **Rejected**: Adds compilation step (protobuf) or dependencies (msgpack). JSON is sufficient for our message complexity and the overhead is acceptable.

### Raw Binary Protocol

Custom binary framing with length prefixes.

- **Rejected**: Harder to debug, more error-prone to implement, no significant performance benefit given that audio generation is the bottleneck.

### Erlang Term Format (ETF)

Native BEAM serialization.

- **Rejected**: Python support requires external libraries (erlang-term). JSON is more universally supported.

### Streaming Audio Chunks

Send audio in chunks as it's generated.

- **Rejected for MVP**: Adds significant complexity. Chatterbox generates complete audio in one call anyway. Can be revisited if latency becomes critical.

### File-based Transfer

Write audio to temp file, return path.

- **Rejected**: Adds filesystem I/O, temp file cleanup complexity, no benefit over in-memory transfer for typical audio sizes (<10MB).

## References

- [JSON RFC 8259](https://datatracker.ietf.org/doc/html/rfc8259)
- [Base64 RFC 4648](https://datatracker.ietf.org/doc/html/rfc4648)
- [Elixir Jason Library](https://hexdocs.pm/jason/)
