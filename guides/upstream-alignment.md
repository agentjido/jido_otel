# Upstream Alignment Proposal (`jido`)

This document captures the proposed upstream coordination work for `Jido.Observe` and tracer adapters.

## Problem Statement

`Jido.Observe` supports both:

- Synchronous scoped spans (`with_span/3`)
- Async lifecycle spans (`start_span/2` + `finish_span/2` / `finish_span_error/4`)

OpenTelemetry current span context is process-local. Tracer adapters that mutate current process span context in `span_start/2` can leak context when spans are finished in another process.

## Proposed Upstream Changes

1. Add a scoped callback path for synchronous span execution.
2. Keep async callbacks explicit and context-neutral by default.
3. Introduce optional behavior callbacks for adapters that need process-scoped activation semantics.
4. Clarify process-local context constraints in `Jido.Observe` docs and examples.

## Candidate API Direction

Example behavior extension (illustrative only):

```elixir
@callback with_span_scope(
            event_prefix(),
            metadata(),
            (-> result)
          ) :: result when result: term()
```

Notes:

- `with_span_scope/3` would be optional and used by `Jido.Observe.with_span/3` when implemented.
- Async `start_span/2` and finish callbacks remain unchanged and must not assume same-process completion.

## Suggested Upstream Issue Draft

Title:

`observe: add scoped tracer callback path for OTP-safe sync spans`

Body outline:

1. Describe process-local OTel context and async finish caveat.
2. Propose optional scoped callback to separate sync and async semantics.
3. Keep existing callback compatibility, with defaults preserving current behavior.
4. Add migration notes for adapter maintainers.

## Status

Opened upstream issue: [agentjido/jido#176](https://github.com/agentjido/jido/issues/176)
