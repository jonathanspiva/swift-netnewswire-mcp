# TODO

## Now

## Later
- [ ] Raise the minimum to macOS 27 once GitHub ships a `macos-27` runner image (still none as of 2026-09-30; only an Xcode 27 image on macOS 26)
- [ ] Sign/notarize the `.mcpb` binary and publish it as a GitHub release asset
- [ ] Expose feeds/articles as MCP Resources (addressable by URI) in addition to tools
- [ ] Cursor-based pagination for the list tools (large accounts)
- [ ] Plugin launcher follow-ups. A 2026-09-30 survey found that the most common
      pattern for compiled MCP servers (grafana/mcp-grafana, ory/lumen,
      lukasmalkmus/moneymoney, etc.) is the one `plugin/launch.sh` already uses: a
      launcher that downloads a version-pinned release asset into
      `CLAUDE_PLUGIN_DATA`. Ours is stricter than all of them, since others check
      the hash against the release's own checksums file or not at all. The
      official marketplace ships no binaries (LSP plugins expect PATH; MCP plugins
      use HTTP or `npx`/`uvx`/`bun`/`docker`). Worth adding:
  - [ ] Prefer a `netnewswire-mcp` already on PATH (Homebrew/local build) before
        downloading, like moneymoney
  - [ ] SessionStart hook to pre-download in the background, so the first tool
        call doesn't wait on the download
  - [ ] Clear stderr hint when the download fails (offline, rate limit)
  - [ ] Evaluate pointing `mcpServers` at the release `.mcpb` URL instead
        (documented, but no one has confirmed native binaries keep their exec bit)

## Never

## Done
- [x] v1.2.0 release: sync warning, orphan-safe counts, Claude Code plugin; plugin
      pin bumped to the v1.2.0 tarball
- [x] Claude Code plugin: repo is its own marketplace (`.claude-plugin/`); the MCP
      command is `plugin/launch.sh`, which downloads the pinned release tarball on
      first run, verifies its SHA-256, and caches it in `${CLAUDE_PLUGIN_DATA}`.
      Validated (`--strict`) in CI; tested end to end with `claude --plugin-dir`
- [x] Sync warning: list, search, and count tools add a note + `sync_warning` when
      the account DB was written in the last 60s (an iCloud sync on 2026-09-30
      wrote one batch over ~16s and a mid-sync query missed the newest rows)
- [x] Starred/unread counts join `statuses` to `articles`, so the status rows NNW
      keeps for purged articles (1,831 in the live iCloud DB) can't inflate them
- [x] Public-repo hygiene: SECURITY.md (private vulnerability reporting),
      CONTRIBUTING.md, bug-report issue form, Dependabot (actions + Swift), CI with
      read-only token / timeout / concurrency / SHA-pinned checkout, README privacy
      section; repo settings (ruleset on main, squash-only, auto-delete branches,
      wiki/projects off, Dependabot alerts + security updates)
- [x] Fit Claude Code's 25k-token tool-output cap: list max 500 → 100 (starred
      default 100 → 50), `get_article` body default 50k → 20k, max 200k → 30k;
      size-budget tests at the max limits
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
