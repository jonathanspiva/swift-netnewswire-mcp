# NetNewsWire MCP Server

[![CI](https://github.com/jonathanspiva/swift-netnewswire-mcp/actions/workflows/ci.yml/badge.svg)](https://github.com/jonathanspiva/swift-netnewswire-mcp/actions/workflows/ci.yml)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
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
| `get_article` | Full article content (HTML/text, authors, dates) by ID |
| `search_articles` | Full-text search using NNW's FTS4 index |
| `get_article_count` | Total, starred, and unread counts |

All tools are read-only. Nothing is modified.

## Requirements

- macOS 26+
- Swift 6.2+
- NetNewsWire (Mac App Store or direct download)

## Build

```bash
swift build -c release
```

The binary will be at `.build/release/netnewswire-mcp`.

## Configure

Add to your Claude Code MCP config (`~/.claude/claude_desktop_config.json` or similar):

```json
{
  "mcpServers": {
    "netnewswire": {
      "command": "/path/to/netnewswire-mcp"
    }
  }
}
```

## How it works

The server reads NetNewsWire's SQLite databases directly (read-only mode) from:

```
~/Library/Containers/com.ranchero.NetNewsWire-Evergreen/Data/Library/Application Support/NetNewsWire/Accounts/
```

It auto-discovers all accounts and their databases on startup. Feed lists are parsed from each account's `Subscriptions.opml` file. Full-text search uses NNW's built-in FTS4 search index.

## Dependencies

- [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) - MCP protocol implementation for Swift
- [GRDB.swift](https://github.com/groue/GRDB.swift) - SQLite toolkit for Swift

## Notes

- This depends on NetNewsWire's internal database schema, which is not a public API and could change between versions.
- Feed IDs are the XML URLs of the feeds, not UUIDs.
- Dates are Unix timestamps (seconds since 1970).

## License

MIT
