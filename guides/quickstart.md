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

## 4. Configure Tracer Runtime Mode

Use OTP-safe behavior by default:

```elixir
config :jido_otel,
  current_span_mode: :safe
```

If you need legacy same-process span activation semantics, set `current_span_mode: :activate_unsafe`.
For async `start_span`/`finish_span` flows across processes, keep `:safe`.

## 5. Emit a Span

```elixir
Jido.Observe.with_span([:jido, :agent, :action, :run], %{agent_id: "agent-1"}, fn ->
  :ok
end)
```

The span name becomes `jido.agent.action.run` and sanitized metadata is attached
as OpenTelemetry attributes. While the callback runs, the Jido span is the
current OpenTelemetry span, so nested OTel-aware libraries create child spans
under it.

Async lifecycle spans remain context-neutral:

```elixir
span_ctx = Jido.Observe.start_span([:jido, :agent, :async], %{agent_id: "agent-1"})
Jido.Observe.finish_span(span_ctx)
```

Terminal span callbacks are idempotent (`first_terminal_call_wins`).
