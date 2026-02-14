# Release Checklist

Use this checklist before publishing a new Hex release.

## Quality Gates

Run all release checks:

```bash
mix release.check
```

This runs:

- `mix quality`
- `mix test`
- `mix docs`
- `mix hex.build`

## Manual Verification

1. Confirm `README.md` examples compile and use current module names.
2. Confirm `CHANGELOG.md` has release notes for user-facing changes.
3. Confirm `mix hex.build` package contents only include intended files.
4. Confirm CI is green on `main`.

## Release Steps

1. Update version and changelog.
2. Create release tag.
3. Push tag to GitHub.
4. Publish to Hex (or trigger release workflow if automated).
