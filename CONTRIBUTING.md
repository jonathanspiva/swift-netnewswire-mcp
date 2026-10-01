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
for the version it pins, so publish the release right after the version bump
merges. Until then, a plugin update to the new version fails to download.

1. On a release branch, bump the version everywhere above.
2. Build the assets from that branch:
   - `./scripts/build-mcpb.sh`, then copy `.build/netnewswire-mcp.mcpb` to
     `netnewswire-mcp-X.Y.Z.mcpb`
   - `tar -czf netnewswire-mcp-X.Y.Z-macos-universal.tar.gz netnewswire-mcp`
     (the binary at the archive root)
   - `shasum -a 256` both files into `SHA256SUMS.txt`
3. Set `SHA256` in `plugin/launch.sh` to the tarball's hash. The binary doesn't
   depend on `launch.sh`, so the assets built in step 2 stay valid.
4. Open a PR, wait for CI, and squash-merge.
5. Immediately tag the merge commit `vX.Y.Z` and publish the GitHub release with
   the three files from step 2 (`gh release create vX.Y.Z --target <sha> ...`).
6. Check the plugin downloads it: run `plugin/launch.sh` with
   `CLAUDE_PLUGIN_DATA` set to an empty directory.

To test the plugin against a local build, set `NETNEWSWIRE_MCP_BIN` to the binary
path before launching `claude --plugin-dir .`.
