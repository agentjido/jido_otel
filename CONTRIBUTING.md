# Contributing to Jido.Otel

Thank you for your interest in contributing to Jido.Otel!

## Development Setup

```bash
git clone https://github.com/agentjido/jido_otel.git
cd jido_otel
mix setup
```

## Running Tests

```bash
# Run tests with coverage
mix test

# Run all quality checks
mix quality

# Run release-grade checks
mix release.check

# Check documentation coverage
mix doctor --raise
```

## Code Style

- Follow standard Elixir conventions
- Code is formatted with `mix format`
- Run `mix credo --strict` before submitting PRs
- Use `mix dialyzer` for type checking

## Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

Examples:
  feat(otel): add trace context propagation
  fix(observer): resolve memory leak in span storage
  docs: update README with examples
```

Valid types:
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `style` - Formatting (no code change)
- `refactor` - Code refactoring (no fix/feature)
- `perf` - Performance improvement
- `test` - Test additions/fixes
- `chore` - Maintenance/tooling
- `ci` - CI/CD changes

## Pull Request Process

1. Create a feature branch: `git checkout -b feat/my-feature`
2. Make your changes
3. Run `mix quality` to verify code quality
4. Run `mix test` to ensure tests pass
5. Commit with conventional commit message
6. Push and create a PR

## Documentation

- All public functions must have `@doc` and `@spec`
- Add examples to module documentation
- Update CHANGELOG.md for user-facing changes
- Keep guides in `guides/` updated for operational workflows

## License

By contributing, you agree your code is licensed under Apache 2.0.
