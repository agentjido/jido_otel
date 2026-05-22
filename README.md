# Jido.Otel

OpenTelemetry extension for the Jido.Observe system.

`Jido.Otel` provides integrated observability instrumentation for Jido-based applications, bridging the Jido ecosystem with standard OpenTelemetry practices.

## What It Does

- Implements `Jido.Observe.Tracer` as `Jido.Otel.Tracer`
- Converts Jido event prefixes to span names (`[:jido, :agent, :run]` -> `jido.agent.run`)
- Sanitizes and maps Jido metadata and measurements to OpenTelemetry attributes
- Records exceptions as OpenTelemetry exception events
- Applies idempotent terminal span handling (`first_terminal_call_wins`)
- Activates synchronous `Jido.Observe.with_span/3` spans as the current OTel span
  for correctly parented nested instrumentation

## Installation

Add `jido_otel` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jido_otel, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Installation via Igniter

(Coming soon)

```bash
mix igniter.install jido_otel
```

## Quick Start

Configure Jido to use the OpenTelemetry tracer:

```elixir
config :jido, :observability,
  tracer: Jido.Otel.Tracer
```

Configure your OpenTelemetry SDK (minimal local baseline):

```elixir
config :opentelemetry,
  traces_exporter: :none
```

Configure tracer current-span behavior (recommended production default):

```elixir
config :jido_otel,
  current_span_mode: :safe
```

Use `Jido.Observe` spans as usual and they will be bridged to OpenTelemetry.
Synchronous `with_span/3` spans are activated only while the callback runs:

```elixir
Jido.Observe.with_span([:jido, :agent, :action, :run], %{agent_id: "agent-1"}, fn ->
  # perform work
  :ok
end)
```

For exporting to an OTLP collector, set your preferred exporter config in your host application.

## Async Safety and Race Policy

`Jido.Otel.Tracer` supports two runtime modes:

- `:safe` (default): does not mutate process-local current span context in `span_start/2`.
- `:activate_unsafe`: preserves legacy same-process activation/restore behavior.

For async `start_span`/`finish_span` flows across processes, use `:safe`.
Synchronous `Jido.Observe.with_span/3` uses `with_span_scope/3`, which activates
the span only in the caller process and restores the previous current span before
returning.

Terminal callbacks (`span_stop/2` and `span_exception/4`) are idempotent. When multiple terminal calls race, the first terminal call wins and later calls are no-op.

## Guides

- [Quickstart](./guides/quickstart.md)
- [Configuration](./guides/configuration.md)
- [Release Checklist](./guides/release-checklist.md)
- [Upstream Alignment Proposal](./guides/upstream-alignment.md)

## Release Quality Checks

Run the full public-release gate locally:

```bash
mix release.check
```

Full documentation is available at [https://hexdocs.pm/jido_otel](https://hexdocs.pm/jido_otel).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.
