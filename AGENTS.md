# AGENTS.md - Jido.Otel Development Guide

## Project Overview

Jido.Otel is an OpenTelemetry extension for the Jido.Observe system, providing integrated observability instrumentation for Jido-based applications.

## Common Commands

### Development
```bash
mix setup          # Setup dev environment
mix compile        # Compile the package
mix test           # Run tests with coverage
mix test --no-cover # Run tests without coverage
mix format         # Format code
mix quality        # Run all quality checks (format, credo, dialyzer, doctor)
```

### Quality Assurance
```bash
mix credo --strict         # Lint with Credo
mix dialyzer               # Type check with Dialyzer
mix doctor --raise         # Check documentation coverage
mix coveralls.html         # Generate coverage report
```

### Documentation
```bash
mix docs           # Generate ExDoc documentation
```

## Project Structure

```
jido_otel/
├── .github/
│   └── workflows/
│       ├── ci.yml              # CI/CD pipeline
│       └── release.yml         # Release automation
├── config/
│   ├── config.exs              # Base configuration
│   ├── dev.exs                 # Development overrides
│   └── test.exs                # Test overrides
├── guides/                     # Optional guides
├── lib/
│   ├── jido_otel.ex           # Main module
│   └── jido_otel/
│       ├── application.ex      # Application supervision
│       └── error.ex            # Error handling
├── test/
│   ├── support/                # Test helpers/fixtures
│   └── jido_otel_test.exs
├── .formatter.exs              # Code formatter config
├── .gitignore
├── AGENTS.md                   # This file
├── CHANGELOG.md                # Version history
├── CONTRIBUTING.md             # Contribution guide
├── LICENSE                     # Apache 2.0
├── mix.exs
├── README.md
└── usage-rules.md              # LLM usage rules
```

## Code Style

- Follow standard Elixir conventions
- Use `Logger` for output
- Handle errors gracefully with pattern matching
- All public functions require `@doc` and `@spec`
- Use Zoi for schema validation
- Use Splode for error composition

## Dependencies

### Core Runtime
- `jido` - Core Jido framework
- `zoi` - Schema validation
- `splode` - Error composition
- `jason` - JSON handling

### Development
- `credo` - Linting
- `dialyxir` - Type checking
- `ex_doc` - Documentation
- `doctor` - Doc coverage
- `excoveralls` - Coverage reports
- `git_hooks` - Git automation
- `git_ops` - Release management
- `mimic` - Mocking

## Git Commit Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

Example types:
- feat: New feature
- fix: Bug fix
- docs: Documentation
- refactor: Code refactoring
- test: Test additions
- chore: Maintenance
```

**Important:** Never add "ampcode" as a contributor in commit messages.

## Testing

```bash
# Run all tests
mix test

# Run tests with coverage report
mix test --cover

# Generate detailed coverage HTML
mix coveralls.html

# Run specific test
mix test test/jido_otel_test.exs

# Run with filter
mix test --only tag_name
```

## Documentation

All public modules and functions must have documentation:

```elixir
defmodule Jido.Otel.Module do
  @moduledoc """
  Brief description of this module.

  ## Overview
  More detailed explanation.

  ## Examples

      iex> Jido.Otel.Module.function(:arg)
      {:ok, :result}
  """

  @doc """
  Function description.

  ## Parameters
    * `arg` - Description

  ## Returns
    * `{:ok, term}` - Success
    * `{:error, reason}` - Failure
  """
  @spec function(term()) :: {:ok, term()} | {:error, term()}
  def function(arg) do
    # Implementation
  end
end
```

## Before Submitting a PR

- [ ] Code passes `mix quality`
- [ ] Tests pass with good coverage (>90%)
- [ ] Documentation is complete (`mix doctor --raise`)
- [ ] CHANGELOG.md is updated
- [ ] Commit messages follow conventional commits
- [ ] No uncommitted changes

## Releasing

Releases are handled via `git_ops`:

```bash
mix git_ops.release
git push origin main --tags
```

This will:
1. Update version in mix.exs
2. Update CHANGELOG.md
3. Create git tag
4. Push to GitHub

Publication to Hex is handled by CI/CD workflow.
