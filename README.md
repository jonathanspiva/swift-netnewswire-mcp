# NetNewsWire MCP Server

[![CI](https://github.com/jonathanspiva/swift-netnewswire-mcp/actions/workflows/ci.yml/badge.svg)](https://github.com/jonathanspiva/swift-netnewswire-mcp/actions/workflows/ci.yml)
[![Swift 6.4](https://img.shields.io/badge/Swift-6.4-orange.svg)](https://swift.org)
[![macOS 26+](https://img.shields.io/badge/macOS-26+-blue.svg)](https://developer.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Built with Claude Code](https://img.shields.io/badge/Built%20with-Claude%20Code-cc785c)](https://claude.ai/code)

A read-only [Model Context Protocol](https://modelcontextprotocol.io) (MCP) server for [NetNewsWire](https://netnewswire.com), the open-source RSS reader for Mac.

Gives AI assistants like Claude access to your NetNewsWire feeds, articles, and search index.

## Tools

| Tool | Description |
|------|-------------|
| `list_accounts` | List available NNW accounts (OnMyMac, iCloud, etc.) |
| `list_feeds` | List subscribed feeds (parsed from OPML) |
| `list_starred_articles` | Starred articles with optional feed filter and limit |
| `list_recent_articles` | Recent articles by arrival date |
| `get_article` | Full article content by ID; optional `format` (html/text) and `max_content_length` to bound the body |
| `search_articles` | Full-text search using NNW's FTS4 index |
| `get_article_count` | Total, starred, and unread counts |

All tools are read-only. Nothing is modified. Each tool returns machine-readable
`structuredContent` (with a declared `outputSchema`) alongside the human-readable
markdown.

Results are sized to fit comfortably in Claude Code's default tool-output limit:
list tools return at most 100 articles (default 50), and `get_article` returns at
most 30,000 characters of body (default 20,000).

## Privacy

Your NetNewsWire databases hold your private reading history: subscriptions,
articles, and what you've starred and read. This server runs locally and never
makes network requests itself, but everything a tool returns is passed to the MCP
client you connect it to, and from there to that client's AI model. Only connect
it to clients you trust with that data.

## Requirements

- macOS 26+
- Swift 6.4+ (Xcode 27, or the swift.org 6.4 toolchain on macOS 26)
- NetNewsWire (Mac App Store or direct download); tested against 7.1.4 (schema unchanged since 7.1.1)

## Build

```bash
swift build -c release
```

The binary will be at `.build/release/netnewswire-mcp`.

## Test

```bash
swift test                          # 118 tests, no NetNewsWire install needed
swift test --enable-code-coverage   # ~98% line coverage
```

Tests run against a fixture database that mirrors NetNewsWire's schema, and drive
the real server over the MCP SDK's in-memory transport (initialize handshake,
tool listing, and a check that every tool's `structuredContent` matches its
declared `outputSchema`). If NetNewsWire is installed and the terminal has Full
Disk Access, one extra test validates the queries against your live database.

## Configure

### Claude Code

`--scope user` makes it available in every project:

```bash
claude mcp add --scope user netnewswire -- /path/to/.build/release/netnewswire-mcp
```

Run `claude mcp list` to confirm it connects, or `/mcp` inside a session.

### Claude desktop app

Build a Desktop Extension (`.mcpb`, needs Node for `npx`) and double-click it,
or install it from Settings → Extensions → Advanced settings → Install Extension:

```bash
./scripts/build-mcpb.sh   # writes .build/netnewswire-mcp.mcpb
```

The bundle is built locally and unsigned. Alternatively, add the binary by hand to
`~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "netnewswire": {
      "command": "/path/to/.build/release/netnewswire-mcp"
    }
  }
}
```

## Full Disk Access

NetNewsWire keeps its databases inside a macOS app container, which the system
protects with privacy controls (TCC). The server can only read it if the process
that launches it has **Full Disk Access**. Without it the server still starts, but
every tool call returns an error explaining how to grant access.

Grant FDA to whichever app hosts your MCP client, then restart that app:

- Running Claude Code from a terminal → System Settings → Privacy & Security →
  Full Disk Access → enable **Terminal** (or iTerm).
- The Claude desktop app → enable **Claude**.
- Another host (e.g. VS Code) → grant FDA to that app instead.

## How it works

The server reads NetNewsWire's SQLite databases directly (read-only mode) from:

```
~/Library/Containers/com.ranchero.NetNewsWire-Evergreen/Data/Library/Application Support/NetNewsWire/Accounts/
```

It auto-discovers all accounts and their databases on startup. Feed lists are parsed from each account's `Subscriptions.opml` file. Full-text search uses NNW's built-in FTS4 search index.

## Dependencies

- [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) 0.12.1+ - MCP protocol implementation for Swift (supports spec 2025-11-25)
- [GRDB.swift](https://github.com/groue/GRDB.swift) 7.11+ - SQLite toolkit for Swift

## Notes

- Only tested with [Claude Code](https://code.claude.com/docs). It should work with any MCP client, but your mileage may vary.
- This depends on NetNewsWire's internal database schema, which is not a public API and could change between versions. NetNewsWire 7.1 moved authors into an inline JSON column on `articles` (the old `authors`/`authorsLookup` tables are gone); this server reads the current layout.
- Feed IDs are the XML URLs of the feeds, not UUIDs.
- Dates are Unix timestamps (seconds since 1970).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please report security issues privately, as
described in [SECURITY.md](SECURITY.md).

## License

MIT
