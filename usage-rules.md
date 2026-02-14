# JidoOtel - LLM Usage Rules

This document provides rules and patterns for AI assistants (Cursor, Claude, etc.) when working with JidoOtel.

## Project Context

**JidoOtel** is an OpenTelemetry extension for the Jido.Observe system. It bridges the Jido ecosystem with standard OpenTelemetry practices for observability.

## Key Principles

1. **Follow GENERIC_PACKAGE_QA.md**: All code patterns and structure follow the Jido ecosystem standards documented in `GENERIC_PACKAGE_QA.md`.

2. **Quality First**: Always run `mix quality` before suggesting changes. Code must pass:
   - Format check (`mix format`)
   - Linting (`mix credo --strict`)
   - Type checking (`mix dialyzer`)
   - Doc coverage (`mix doctor --raise`)

3. **No Helper Functions in mix.exs**: Never use `jido_dep/4` or similar helper functions. Use direct dependencies with versions or GitHub references.

4. **Zoi for Validation**: All core structs must use Zoi schemas for validation:
   - Define `@schema Zoi.struct(__MODULE__, %{...})`
   - Implement `new/1` and `new!/1` functions
   - Use `Zoi.parse/2` for validation

5. **Splode for Errors**: All error handling uses Splode:
   - Define error classes (e.g., `:invalid`, `:execution`, `:config`)
   - Concrete `...Error` structs for raising/matching
   - Helpers for common errors (`validation_error/2`, etc.)

## Code Patterns

### Modules

Every public module must have:
- `@moduledoc` with overview and examples
- All functions with `@doc` and `@spec`
- Clear public/private separation

### Testing

- All public functions must have tests
- Aim for >90% coverage
- Use `ExUnit` for testing
- Tag tests appropriately (`:unit`, `:integration`, etc.)

### Documentation

- Module docs include "Overview", "Examples", and any relevant sections
- Function docs include "Parameters", "Returns", and examples
- CHANGELOG.md updated for user-facing changes
- Use ExDoc format (see README.md and guides)

### Git Workflow

- Use conventional commits (feat, fix, docs, etc.)
- Never add "ampcode" as a contributor
- Keep commits focused and logical
- Update CHANGELOG.md before release

## File Locations

- **Core logic**: `lib/jido_otel/`
- **Tests**: `test/` with matching structure
- **Test helpers**: `test/support/`
- **Config**: `config/{config,dev,test}.exs`
- **Docs**: `guides/` for longer guides

## Common Tasks

### Adding a New Module

1. Create `lib/jido_otel/module_name.ex`
2. Define Zoi schema if struct-based
3. Add comprehensive `@moduledoc` and `@doc`
4. Create tests in `test/module_name_test.exs`
5. Run `mix quality && mix test`
6. Update CHANGELOG.md

### Error Handling

```elixir
# In JidoOtel.Error module
defmodule TraceError do
  @moduledoc "Error for tracing failures."
  defexception [:message, :details]
end

# Usage
raise JidoOtel.Error.trace_error("Failed to create span", span_id: "123")
```

### Configuration

All config goes in `config/config.exs` with environment overrides:
- `dev.exs` for development
- `test.exs` for testing

## References

- **AGENTS.md**: Development commands and structure
- **CONTRIBUTING.md**: Contribution workflow
- **GENERIC_PACKAGE_QA.md**: Ecosystem standards (parent directory)
- **mix.exs**: Project configuration with all dependencies

## Quality Checklist

Before suggesting any changes:

- [ ] Code follows Elixir conventions
- [ ] All public APIs are documented
- [ ] Tests included for new functionality
- [ ] `mix quality` passes
- [ ] No dependency conflicts
- [ ] CHANGELOG.md updated if user-facing
