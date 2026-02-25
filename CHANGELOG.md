# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `Jido.Otel.Tracer` implementation for `Jido.Observe.Tracer`
- OpenTelemetry runtime dependencies and baseline SDK configuration
- Tracer lifecycle contract coverage for start/stop/exception flows
- Public guides for quickstart, configuration, and release checklist
- `:jido_otel` runtime config with `current_span_mode` (`:safe` default, `:activate_unsafe` opt-in)
- OTP race-condition regression coverage for async finish and concurrent terminal callbacks
- Upstream alignment proposal guide for `Jido.Observe` tracer callback evolution

### Changed
- Public namespace standardized to `Jido.Otel` across code, docs, and tests
- Hex package metadata tightened for public release quality
- ExDoc configuration now publishes guides and changelog as extras
- `Jido.Otel.Tracer` now uses an internal typed context struct and idempotent terminal semantics (`first_terminal_call_wins`)
- Default tracer lifecycle is OTP-safe for async completion; `:activate_unsafe` mode preserves legacy activation behavior with cross-process warning logs
- CI/release workflows now pin reusable workflow refs to immutable SHAs and remove release-time test skipping input
- `mix quality` now includes compile warnings as errors and checks for unused lockfile dependencies

## [0.1.0] - 2026-02-14

Initial release.

[Unreleased]: https://github.com/agentjido/jido_otel/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/agentjido/jido_otel/releases/tag/v0.1.0
