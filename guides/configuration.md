# Configuration

`Jido.Otel` uses two configuration surfaces:

- `:jido` for selecting the tracer implementation.
- `:jido_otel` for tracer runtime behavior.
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

## Jido.Otel Runtime Config

Use `:jido_otel` to configure current-span activation behavior:

```elixir
config :jido_otel,
  current_span_mode: :safe
```

Valid values:

- `:safe` (default): does not set current process span in `span_start/2`. Recommended for production and async workloads.
- `:activate_unsafe`: preserves same-process activation/restore behavior. Use only when you explicitly need legacy current-span activation semantics.

If `:activate_unsafe` is enabled and `span_stop/2` or `span_exception/4` runs in another process, restore is skipped and a warning is logged.

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

`Jido.Otel.Tracer` terminal callbacks are idempotent (`first_terminal_call_wins`): if `span_stop/2` and `span_exception/4` race for the same span context, only the first terminal call applies status/events and ends the span.
