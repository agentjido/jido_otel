# JidoOtel

OpenTelemetry extension for the Jido.Observe system.

JidoOtel provides integrated observability instrumentation for Jido-based applications, bridging the Jido ecosystem with standard OpenTelemetry practices.

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

```elixir
# Start observability instrumentation
JidoOtel.start_link([])
```

## Documentation

Full documentation is available at [https://hexdocs.pm/jido_otel](https://hexdocs.pm/jido_otel).

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution guidelines.

## License

Apache License 2.0 - see [LICENSE](./LICENSE) for details.
