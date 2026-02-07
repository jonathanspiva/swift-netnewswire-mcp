import Foundation
import MCP

// MARK: - Tool Definitions

extension ToolHandlers {

    static let readOnly = Tool.Annotations(
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false
    )

    public static let listAccountsTool = Tool(
        name: "list_accounts",
        description: "List available NetNewsWire accounts (OnMyMac, iCloud, etc.)",
        inputSchema: .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
        ]),
        annotations: readOnly
    )

    public static let listFeedsTool = Tool(
        name: "list_feeds",
        description: "List subscribed feeds for an account (parsed from OPML). Returns feed title, folder, and URL.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "account": .object([
                    "type": .string("string"),
                    "description": .string("Account name (e.g. 'OnMyMac', '2_iCloud'). Defaults to first account."),
                ]),
            ]),
            "additionalProperties": .bool(false),
        ]),
        annotations: readOnly
    )

    public static let listStarredArticlesTool = Tool(
        name: "list_starred_articles",
        description: "List starred articles with article ID, title, feed, date, and URL. Supports optional feed filter and limit.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "account": .object([
                    "type": .string("string"),
                    "description": .string("Account name. Defaults to first account."),
                ]),
                "feed_id": .object([
                    "type": .string("string"),
                    "description": .string("Filter by feed ID (the feed's XML URL)"),
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Max articles to return (default: 100)"),
                ]),
            ]),
            "additionalProperties": .bool(false),
        ]),
        annotations: readOnly
    )

    public static let listRecentArticlesTool = Tool(
        name: "list_recent_articles",
        description: "List recent articles with article ID, ordered by arrival date. Supports feed filter, limit, and starred-only filter.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "account": .object([
                    "type": .string("string"),
                    "description": .string("Account name. Defaults to first account."),
                ]),
                "feed_id": .object([
                    "type": .string("string"),
                    "description": .string("Filter by feed ID (the feed's XML URL)"),
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Max articles to return (default: 50)"),
                ]),
                "starred_only": .object([
                    "type": .string("boolean"),
                    "description": .string("Only return starred articles (default: false)"),
                ]),
            ]),
            "additionalProperties": .bool(false),
        ]),
        annotations: readOnly
    )

    public static let getArticleTool = Tool(
        name: "get_article",
        description: "Get full article content (HTML/text, URL, authors, dates) by article ID",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "account": .object([
                    "type": .string("string"),
                    "description": .string("Account name. Defaults to first account."),
                ]),
                "article_id": .object([
                    "type": .string("string"),
                    "description": .string("The article ID"),
                ]),
            ]),
            "required": .array([.string("article_id")]),
            "additionalProperties": .bool(false),
        ]),
        annotations: readOnly
    )

    public static let searchArticlesTool = Tool(
        name: "search_articles",
        description: "Full-text search across article titles and content using NNW's built-in search index",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "account": .object([
                    "type": .string("string"),
                    "description": .string("Account name. Defaults to first account."),
                ]),
                "query": .object([
                    "type": .string("string"),
                    "description": .string("Search query (FTS4 syntax: words, phrases in quotes, OR, NOT)"),
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Max results to return (default: 50)"),
                ]),
            ]),
            "required": .array([.string("query")]),
            "additionalProperties": .bool(false),
        ]),
        annotations: readOnly
    )

    public static let getArticleCountTool = Tool(
        name: "get_article_count",
        description: "Get counts of total, starred, and unread articles for an account",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "account": .object([
                    "type": .string("string"),
                    "description": .string("Account name. Defaults to first account."),
                ]),
            ]),
            "additionalProperties": .bool(false),
        ]),
        annotations: readOnly
    )
}
