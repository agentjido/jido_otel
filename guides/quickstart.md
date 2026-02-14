# Quickstart

This guide shows the minimum setup to run `Jido.Otel.Tracer` with a Jido app.

## 1. Add Dependency

```elixir
def deps do
  [
    {:jido_otel, "~> 0.1.0"}
  ]
end
```

## 2. Configure Jido Tracer

```elixir
config :jido, :observability,
  tracer: Jido.Otel.Tracer
```

## 3. Configure OpenTelemetry SDK

Start with a safe baseline during development:

```elixir
config :opentelemetry,
  traces_exporter: :none
```

To export traces in production, configure an exporter in your host app.

## 4. Emit a Span

```elixir
Jido.Observe.with_span([:jido, :agent, :action, :run], %{agent_id: "agent-1"}, fn ->
  :ok
end)
```

The span name becomes `jido.agent.action.run` and metadata is attached as OpenTelemetry attributes.
