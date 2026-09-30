# Contributing

Bug reports and pull requests are welcome.

## Development

Requires Swift 6.4+ on macOS 26 or later.

```bash
swift build
swift test
```

Tests run against a fixture database and don't need NetNewsWire installed. If
NetNewsWire is installed and your terminal has Full Disk Access, one extra test
checks the queries against your live database. It only asserts on shape and
never prints or records your data.

## Guidelines

- Keep the server read-only. No tool may modify NetNewsWire data.
- Add tests for any change. New or changed tools need a case in the
  structured-output contract test (`ServerTests.swift`), and results must stay
  within the output size budget.
- Test data must be fictional. Never copy titles, feeds, or authors from a real
  database into fixtures.
- If you change the server version, update `mcpb/manifest.json` to match (a test
  enforces this).
