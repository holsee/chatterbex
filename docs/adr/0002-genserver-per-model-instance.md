# ADR-0002: GenServer Per Model Instance

## Status

Accepted

## Date

2024-12-25

## Context

Chatterbex wraps three different Chatterbox model variants:

- **Turbo** (350M params) - Low-latency English TTS
- **English** (500M params) - High-quality English with CFG controls
- **Multilingual** (500M params) - 23+ language support

Each model requires:
- Loading weights into GPU/CPU memory (1-2 GB per model)
- Maintaining state between requests (loaded model, device context)
- Serializing access (one inference at a time per model)

Applications may need:
- Multiple instances of the same model (horizontal scaling)
- Different models running simultaneously
- Named processes for easy access across the application

## Decision

Implement a GenServer (`Chatterbex.Server`) that encapsulates one model instance and its associated Python Port.

```elixir
# Start multiple independent instances
{:ok, turbo1} = Chatterbex.start_link(model: :turbo)
{:ok, turbo2} = Chatterbex.start_link(model: :turbo)
{:ok, multi} = Chatterbex.start_link(model: :multilingual)

# Or use named processes
{:ok, _} = Chatterbex.start_link(model: :turbo, name: MyApp.TTS)
Chatterbex.generate(MyApp.TTS, "Hello!")
```

Each GenServer:
- Owns exactly one Python Port
- Manages request/response correlation
- Handles Port lifecycle (startup, crash recovery via supervision)
- Provides synchronous API with configurable timeouts

## Consequences

### Positive

- **Flexible scaling**: Start as many instances as needed
- **Isolation**: Each model instance is independent; crashes don't affect others
- **OTP compatibility**: Works with Supervisors, DynamicSupervisors, and Registries
- **Simple mental model**: One GenServer = one model = one Python process
- **Named access**: Optional `:name` parameter for application-wide singletons
- **Backpressure**: GenServer naturally serializes requests to each model

### Negative

- **Memory overhead**: Each instance loads its own model copy
- **No request pooling**: Built-in—applications must implement their own if needed
- **Startup time**: Each new instance requires model loading (30-60s)

### Neutral

- Applications decide their own supervision strategy
- No global state or shared model instances

## Alternatives Considered

### Singleton Model Registry

A single process managing all models with internal routing.

- **Rejected**: More complex, harder to scale, single point of failure, doesn't leverage OTP patterns well.

### Connection Pool (Poolboy/NimblePool)

Pool of pre-started model instances.

- **Rejected**: Premature optimization. Users can easily add pooling on top of the GenServer abstraction if needed. The base API should be simple.

### Supervised Model Process + Separate Client API

Split the Port owner from the client-facing API.

- **Rejected**: Adds indirection without clear benefit. The GenServer already provides the right abstraction level.

### Module-based API (No GenServer)

Functions that spawn Ports per request.

- **Rejected**: Model loading takes 30-60 seconds; cannot reload per request. Need persistent processes.

## References

- [GenServer Documentation](https://hexdocs.pm/elixir/GenServer.html)
- [OTP Design Principles](https://www.erlang.org/doc/design_principles/des_princ.html)
