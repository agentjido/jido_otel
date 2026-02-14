# Jido.Otel

OpenTelemetry extension for the Jido.Observe system.

`Jido.Otel` provides integrated observability instrumentation for Jido-based applications, bridging the Jido ecosystem with standard OpenTelemetry practices.

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

Use `Jido.Observe` spans as usual and they will be bridged to OpenTelemetry:

```elixir
Jido.Observe.with_span([:jido, :agent, :action, :run], %{agent_id: "agent-1"}, fn ->
  # perform work
  :ok
end)
```

For exporting to an OTLP collector, set your preferred exporter config in your host application.

Full documentation is available at [https://hexdocs.pm/jido_otel](https://hexdocs.pm/jido_otel).

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution guidelines.

## License

Apache License 2.0 - see [LICENSE](./LICENSE) for details.
