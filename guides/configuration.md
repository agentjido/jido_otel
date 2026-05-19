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
- `Jido.Otel.Tracer.with_span_scope/3` for synchronous `with_span/3` calls

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

Synchronous `Jido.Observe.with_span/3` does not depend on `:activate_unsafe`.
`Jido.Otel.Tracer.with_span_scope/3` activates the OTel span only while the
callback runs in the caller process, which lets nested OTel instrumentation use
the Jido span as its parent without leaking current-span context into async
finish paths.

## Attribute Mapping Rules

`Jido.Otel.Tracer` sanitizes metadata and measurements into OpenTelemetry attributes:

- Atom keys become string keys (for example `:agent_id` -> `"agent_id"`).
- Atom values become strings.
- Sensitive keys such as `:api_key`, `:authorization`, `:password`, `:secret`,
  and `:token` are redacted.
- Raw `:stacktrace` metadata is omitted from span attributes.
- Long strings are truncated.
- Homogeneous primitive lists remain bounded OTel-compatible lists.
- Complex values are sanitized, bounded, made inspect-safe, and serialized via
  `inspect/2`.

Exception spans additionally include:

- Span status `:error`
- Exception event named `:exception`
- Attributes `error.kind` and `error.reason`

`jido_otel` is an adapter over Jido's canonical observe/telemetry surfaces. It
does not define Jido runtime semantics privately; future metrics or event bridges
should consume package telemetry rather than create a second instrumentation
path.

`Jido.Otel.Tracer` terminal callbacks are idempotent (`first_terminal_call_wins`): if `span_stop/2` and `span_exception/4` race for the same span context, only the first terminal call applies status/events and ends the span.
