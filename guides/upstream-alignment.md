# Upstream Alignment (`jido`)

This document captures the upstream coordination work for `Jido.Observe` and
tracer adapters.

## Problem Statement

`Jido.Observe` supports both:

- Synchronous scoped spans (`with_span/3`)
- Async lifecycle spans (`start_span/2` + `finish_span/2` / `finish_span_error/4`)

OpenTelemetry current span context is process-local. Tracer adapters that mutate current process span context in `span_start/2` can leak context when spans are finished in another process.

## Upstream Changes

Implemented in `jido`:

1. `Jido.Observe.Tracer` exposes optional `with_span_scope/3`.
2. `Jido.Observe.with_span/3` uses `with_span_scope/3` when the configured
   tracer implements it.
3. Async callbacks remain explicit and context-neutral by default.
4. `Jido.Observe` documents process-local context constraints for sync versus
   async spans.

## Callback API

Tracer behavior extension:

```elixir
@callback with_span_scope(
            event_prefix(),
            metadata(),
            (-> result)
          ) :: result when result: term()
```

Notes:

- `with_span_scope/3` is optional and used by `Jido.Observe.with_span/3` when implemented.
- Async `start_span/2` and finish callbacks remain unchanged and must not assume same-process completion.

## Adapter Guidance

`Jido.Otel.Tracer` implements `with_span_scope/3` by activating the OTel span
only for the duration of the synchronous callback and restoring the previous
current span before returning. This keeps nested same-process OTel
instrumentation correctly parented while preserving safe async lifecycle behavior
for `start_span/2` and terminal callbacks.

Adapter implementations should:

1. Call the provided function in the caller process.
2. Call the provided function exactly once.
3. Preserve the function return value.
4. Preserve exception, throw, and exit semantics.
5. Keep async `span_start/2` context-neutral unless a caller explicitly opts into
   unsafe same-process activation behavior.

## Status

Upstream issue: [agentjido/jido#176](https://github.com/agentjido/jido/issues/176)
