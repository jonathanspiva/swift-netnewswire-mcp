# TODO

## Now

## Later
- [ ] Raise the minimum to macOS 27 once GitHub ships a `macos-27` runner image (hosted runners top out at macOS 26 / Xcode 26.6 today)
- [ ] Package as a Claude Code plugin (`.claude-plugin/plugin.json` with `mcpServers`) if it gets shared beyond personal use
- [ ] Sign/notarize the `.mcpb` binary and publish it as a GitHub release asset
- [ ] Expose feeds/articles as MCP Resources (addressable by URI) in addition to tools
- [ ] Cursor-based pagination for the list tools (large accounts)

## Never

## Done
- [x] Swift 6.4: `swift-tools-version:6.4`, all upcoming features the 6.4 compiler
      offers plus strict memory safety, explicit `public import`s; CI installs the
      swift.org 6.4 toolchain on the macOS 26 runner
- [x] Test coverage from ~88% to ~98% of lines (116 tests): protocol-level tests via
      the in-memory transport, outputSchema contract check for every tool,
      discovery failures, error messages, corrupt-DB handling
- [x] Refresh for Swift 6.4 / macOS 27 / NetNewsWire 7.1.4: builds warning-free,
      98 tests pass (incl. live DB), live schema verified unchanged from 7.1.1,
      GRDB bumped to 7.11.1, CI on `actions/checkout@v7`, README Claude config fixed
- [x] Claude best practices: server `title` in `initialize`, server stays up and
      reports Full Disk Access fixes via tool errors instead of exiting, Claude
      Desktop Extension (`mcpb/manifest.json` + `scripts/build-mcpb.sh`, validated in CI)
- [x] Fix OPML folder tracking (folder context now scoped via an outline stack:
      cleared on `didEndElement`, so sibling folders, nested folders, and
      top-level feeds after a folder are labeled correctly)
- [x] Read authors from the inline `articles.authors` JSON column (NetNewsWire 7.1
      removed the `authors`/`authorsLookup` tables; `get_article` was broken on
      real data before this)
- [x] Build against the Swift 6.3 toolchain (bumped swift-sdk to 0.12.1, adopted
      the new `Content.text` API)
- [x] Clamp `limit` arguments (reject negative/zero/oversized values)
- [x] MCP best practices: register handlers before `start()`, add server
      `instructions`, return `structuredContent` + `outputSchema`, add tool
      titles, bound `get_article` output (`format` / `max_content_length`),
      sanitize error messages, cache one read-only pool per account with a busy timeout
- [x] Escape markdown table cells fully (pipes + newlines, URL columns)
- [x] Test suite: 98 tests — DB query layer against a fixture DB matching the
      live 7.1.1 schema, OPML edge cases, limit/content-length clamping, account
      resolution, structured output, content selection/truncation, author-JSON
      parsing, handler routing/errors, plus a gated live-DB validation test
