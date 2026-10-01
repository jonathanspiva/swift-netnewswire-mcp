import Foundation
import MCP

// MARK: - Structured Tool Output
//
// Modern MCP clients can consume `structuredContent` (machine-readable JSON)
// alongside the human-readable markdown text. These builders produce that JSON,
// and `OutputSchemas` declares the matching `outputSchema` for each tool so
// clients can validate. Field names are snake_case to match the input params.

public enum StructuredOutput {

    /// Choose which body to return for an article and truncate it to `maxLength`.
    /// Shared by the markdown formatter and the structured builder so both agree.
    static func selectContent(
        _ article: ArticleWithStatus,
        preferText: Bool,
        maxLength: Int
    ) -> (text: String?, format: String, truncated: Bool) {
        let chosen: String?
        let format: String
        if preferText {
            chosen = (article.contentText?.isEmpty == false) ? article.contentText : article.contentHTML
            format = (article.contentText?.isEmpty == false) ? "text" : "html"
        } else {
            chosen = (article.contentHTML?.isEmpty == false) ? article.contentHTML : article.contentText
            format = (article.contentHTML?.isEmpty == false) ? "html" : "text"
        }
        guard let content = chosen, !content.isEmpty else { return (nil, format, false) }
        if content.count > maxLength {
            let truncated = String(content.prefix(maxLength))
            let remaining = content.count - maxLength
            return (
                truncated + "\n\n[... truncated \(remaining) more characters. Raise max_content_length to see the rest.]",
                format,
                true
            )
        }
        return (content, format, false)
    }

    // MARK: Value builders

    static func article(_ a: ArticleWithStatus) -> Value {
        .object([
            "article_id": .string(a.articleID),
            "feed_id": .string(a.feedID),
            "title": a.title.map(Value.string) ?? .null,
            "url": (a.url ?? a.externalURL).map(Value.string) ?? .null,
            "date_published": a.datePublished.map(Value.double) ?? .null,
            "date_arrived": .double(a.dateArrived),
            "starred": .bool(a.starred),
            "read": .bool(a.read),
        ])
    }

    static func articleList(_ articles: [ArticleWithStatus]) -> Value {
        .object([
            "articles": .array(articles.map(article)),
            "total": .int(articles.count),
        ])
    }

    static func articleDetail(
        _ a: ArticleWithStatus,
        authors: [Author],
        preferText: Bool,
        maxContentLength: Int
    ) -> Value {
        let (content, format, truncated) = selectContent(a, preferText: preferText, maxLength: maxContentLength)
        return .object([
            "article_id": .string(a.articleID),
            "feed_id": .string(a.feedID),
            "title": a.title.map(Value.string) ?? .null,
            "url": a.url.map(Value.string) ?? .null,
            "external_url": a.externalURL.map(Value.string) ?? .null,
            "summary": a.summary.map(Value.string) ?? .null,
            "date_published": a.datePublished.map(Value.double) ?? .null,
            "date_arrived": .double(a.dateArrived),
            "starred": .bool(a.starred),
            "read": .bool(a.read),
            "authors": .array(authors.compactMap { $0.name }.map(Value.string)),
            "content": content.map(Value.string) ?? .null,
            "content_format": .string(format),
            "content_truncated": .bool(truncated),
        ])
    }

    static func feedList(_ feeds: [FeedInfo]) -> Value {
        .object([
            "feeds": .array(feeds.map { feed in
                .object([
                    "title": .string(feed.title),
                    "folder": feed.folder.map(Value.string) ?? .null,
                    "xml_url": .string(feed.xmlUrl),
                    "html_url": feed.htmlUrl.map(Value.string) ?? .null,
                ])
            }),
            "total": .int(feeds.count),
        ])
    }

    static func counts(account: String, total: Int, starred: Int, unread: Int) -> Value {
        .object([
            "account": .string(account),
            "total": .int(total),
            "starred": .int(starred),
            "unread": .int(unread),
        ])
    }

    static func accountList(_ accounts: [NNWAccount]) -> Value {
        .object([
            "accounts": .array(accounts.map { account in
                .object([
                    "name": .string(account.name),
                    "path": .string(account.path),
                    "has_opml": .bool(account.opmlPath != nil),
                ])
            }),
            "total": .int(accounts.count),
        ])
    }
}

// MARK: - Output Schemas

enum OutputSchemas {
    private static func object(_ properties: [String: Value], required: [String]) -> Value {
        .object([
            "type": .string("object"),
            "properties": .object(properties),
            "required": .array(required.map(Value.string)),
        ])
    }

    private static func prop(_ type: String, nullable: Bool = false) -> Value {
        let typeValue: Value = nullable ? .array([.string(type), .string("null")]) : .string(type)
        return .object(["type": typeValue])
    }

    private static func arrayOf(_ items: Value) -> Value {
        .object(["type": .string("array"), "items": items])
    }

    private static let articleItem = object([
        "article_id": prop("string"),
        "feed_id": prop("string"),
        "title": prop("string", nullable: true),
        "url": prop("string", nullable: true),
        "date_published": prop("number", nullable: true),
        "date_arrived": prop("number"),
        "starred": prop("boolean"),
        "read": prop("boolean"),
    ], required: ["article_id", "feed_id", "date_arrived", "starred", "read"])

    static let articleList = object([
        "articles": arrayOf(articleItem),
        "total": prop("integer"),
        // Only present when NNW wrote to the DB in the last minute
        // (see `ToolHandlers.syncWarning`), so never required.
        "sync_warning": prop("string"),
    ], required: ["articles", "total"])

    static let articleDetail = object([
        "article_id": prop("string"),
        "feed_id": prop("string"),
        "title": prop("string", nullable: true),
        "url": prop("string", nullable: true),
        "external_url": prop("string", nullable: true),
        "summary": prop("string", nullable: true),
        "date_published": prop("number", nullable: true),
        "date_arrived": prop("number"),
        "starred": prop("boolean"),
        "read": prop("boolean"),
        "authors": arrayOf(prop("string")),
        "content": prop("string", nullable: true),
        "content_format": prop("string"),
        "content_truncated": prop("boolean"),
    ], required: ["article_id", "feed_id", "date_arrived", "starred", "read", "authors", "content_format", "content_truncated"])

    static let feedList = object([
        "feeds": arrayOf(object([
            "title": prop("string"),
            "folder": prop("string", nullable: true),
            "xml_url": prop("string"),
            "html_url": prop("string", nullable: true),
        ], required: ["title", "xml_url"])),
        "total": prop("integer"),
    ], required: ["feeds", "total"])

    static let counts = object([
        "account": prop("string"),
        "total": prop("integer"),
        "starred": prop("integer"),
        "unread": prop("integer"),
        "sync_warning": prop("string"),
    ], required: ["account", "total", "starred", "unread"])

    static let accountList = object([
        "accounts": arrayOf(object([
            "name": prop("string"),
            "path": prop("string"),
            "has_opml": prop("boolean"),
        ], required: ["name", "path", "has_opml"])),
        "total": prop("integer"),
    ], required: ["accounts", "total"])
}
