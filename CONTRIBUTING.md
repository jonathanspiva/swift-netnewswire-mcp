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
- If you change the server version, update `mcpb/manifest.json`,
  `.claude-plugin/plugin.json`, and `VERSION` in `plugin/launch.sh` to match
  (tests enforce this).

## Releasing

Plugin users install from `main`, and the launcher downloads the release tarball
for the version it pins. So every version on `main` must already have a published
release. Do the release in one PR:

1. Bump the version everywhere above.
2. Build the universal tarball and publish the GitHub release `vX.Y.Z` with
   `netnewswire-mcp-X.Y.Z-macos-universal.tar.gz` and `SHA256SUMS.txt`.
3. Set `SHA256` in `plugin/launch.sh` to the tarball's line in `SHA256SUMS.txt`,
   test with `claude --plugin-dir .`, then merge. Plugin users get the new
   version on their next plugin update.

To test the plugin against a local build, set `NETNEWSWIRE_MCP_BIN` to the binary
path before launching `claude --plugin-dir .`.
