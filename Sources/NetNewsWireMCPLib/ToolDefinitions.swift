import Foundation
public import MCP

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
        title: "List Accounts",
        description: "List available NetNewsWire accounts (OnMyMac, iCloud, etc.)",
        inputSchema: .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
        ]),
        annotations: readOnly,
        outputSchema: OutputSchemas.accountList
    )

    public static let listFeedsTool = Tool(
        name: "list_feeds",
        title: "List Feeds",
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
        annotations: readOnly,
        outputSchema: OutputSchemas.feedList
    )

    public static let listStarredArticlesTool = Tool(
        name: "list_starred_articles",
        title: "List Starred Articles",
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
                    "description": .string("Max articles to return (default: 50, max: 100)"),
                ]),
            ]),
            "additionalProperties": .bool(false),
        ]),
        annotations: readOnly,
        outputSchema: OutputSchemas.articleList
    )

    public static let listRecentArticlesTool = Tool(
        name: "list_recent_articles",
        title: "List Recent Articles",
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
                    "description": .string("Max articles to return (default: 50, max: 100)"),
                ]),
                "starred_only": .object([
                    "type": .string("boolean"),
                    "description": .string("Only return starred articles (default: false)"),
                ]),
            ]),
            "additionalProperties": .bool(false),
        ]),
        annotations: readOnly,
        outputSchema: OutputSchemas.articleList
    )

    public static let getArticleTool = Tool(
        name: "get_article",
        title: "Get Article",
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
                "format": .object([
                    "type": .string("string"),
                    "enum": .array([.string("html"), .string("text")]),
                    "description": .string("Prefer HTML or plain-text body when both exist (default: html)"),
                ]),
                "max_content_length": .object([
                    "type": .string("integer"),
                    "description": .string("Truncate the article body to this many characters (default: 20000, max: 30000)"),
                ]),
            ]),
            "required": .array([.string("article_id")]),
            "additionalProperties": .bool(false),
        ]),
        annotations: readOnly,
        outputSchema: OutputSchemas.articleDetail
    )

    public static let searchArticlesTool = Tool(
        name: "search_articles",
        title: "Search Articles",
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
                    "description": .string("Max results to return (default: 50, max: 100)"),
                ]),
            ]),
            "required": .array([.string("query")]),
            "additionalProperties": .bool(false),
        ]),
        annotations: readOnly,
        outputSchema: OutputSchemas.articleList
    )

    public static let getArticleCountTool = Tool(
        name: "get_article_count",
        title: "Get Article Counts",
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
        annotations: readOnly,
        outputSchema: OutputSchemas.counts
    )
}
