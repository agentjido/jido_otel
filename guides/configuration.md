# Configuration

`Jido.Otel` uses two configuration surfaces:

- `:jido` for selecting the tracer implementation.
- `:opentelemetry` for SDK/exporter behavior.

## Jido Observability Config

```elixir
config :jido, :observability,
  tracer: Jido.Otel.Tracer
```

`Jido.Observe` will call:

- `Jido.Otel.Tracer.span_start/2`
- `Jido.Otel.Tracer.span_stop/2`
- `Jido.Otel.Tracer.span_exception/4`

## OpenTelemetry SDK Config

Development baseline:

```elixir
config :opentelemetry,
  traces_exporter: :none
```

Example OTLP export (requires corresponding exporter dependency/config in host app):

```elixir
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp
```

## Attribute Mapping Rules

`Jido.Otel.Tracer` normalizes metadata and measurements into OpenTelemetry attributes:

- Atom keys become string keys (for example `:agent_id` -> `"agent_id"`).
- Atom values become strings.
- Homogeneous primitive lists remain lists.
- Complex values are serialized via `inspect/2`.

Exception spans additionally include:

- Span status `:error`
- Exception event named `:exception`
- Attributes `error.kind` and `error.reason`
