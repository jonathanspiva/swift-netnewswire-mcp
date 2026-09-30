import Foundation
import MCP

// MARK: - Read Handler Implementations

extension ToolHandlers {

    /// Build a text content block using the current MCP SDK API.
    static func text(_ value: String) -> Tool.Content {
        .text(text: value, annotations: nil, _meta: nil)
    }

    /// Bundle human-readable markdown with machine-readable structured output.
    static func result(_ markdown: String, structured: Value) -> CallTool.Result {
        // Cast selects the non-throwing `structuredContent: Value?` initializer
        // over the generic `Encodable` one.
        CallTool.Result(content: [text(markdown)], structuredContent: structured as Value?)
    }

    static func handleListAccounts(database: NNWDatabase) -> CallTool.Result {
        let accounts = database.listAccounts()
        return result(
            Formatters.formatAccountList(accounts),
            structured: StructuredOutput.accountList(accounts)
        )
    }

    static func handleListFeeds(
        args: [String: Value],
        database: NNWDatabase
    ) throws -> CallTool.Result {
        let account = try database.resolveAccount(args["account"]?.stringValue)
        let feeds = try database.listFeeds(account: account)
        return result(
            Formatters.formatFeedTable(feeds),
            structured: StructuredOutput.feedList(feeds)
        )
    }

    static func handleListStarredArticles(
        args: [String: Value],
        database: NNWDatabase
    ) throws -> CallTool.Result {
        let account = try database.resolveAccount(args["account"]?.stringValue)
        let feedID = args["feed_id"]?.stringValue
        let limit = resolveLimit(args, default: 50)

        let articles = try database.starredArticles(account: account, feedID: feedID, limit: limit)
        return result(
            Formatters.formatArticleTable(articles, title: "# Starred Articles\n"),
            structured: StructuredOutput.articleList(articles)
        )
    }

    static func handleListRecentArticles(
        args: [String: Value],
        database: NNWDatabase
    ) throws -> CallTool.Result {
        let account = try database.resolveAccount(args["account"]?.stringValue)
        let feedID = args["feed_id"]?.stringValue
        let limit = resolveLimit(args, default: 50)
        let starredOnly = args["starred_only"]?.boolValue ?? false

        let articles = try database.recentArticles(
            account: account,
            feedID: feedID,
            limit: limit,
            starredOnly: starredOnly
        )
        let title = starredOnly ? "# Recent Starred Articles\n" : "# Recent Articles\n"
        return result(
            Formatters.formatArticleTable(articles, title: title),
            structured: StructuredOutput.articleList(articles)
        )
    }

    static func handleGetArticle(
        args: [String: Value],
        database: NNWDatabase
    ) throws -> CallTool.Result {
        let account = try database.resolveAccount(args["account"]?.stringValue)
        let articleID = try requireString(args, key: "article_id")
        let preferText = args["format"]?.stringValue == "text"
        let maxContentLength = resolveContentLength(args)

        let (article, authors) = try database.getArticle(account: account, articleID: articleID)
        return result(
            Formatters.formatArticleDetail(
                article,
                authors: authors,
                preferText: preferText,
                maxContentLength: maxContentLength
            ),
            structured: StructuredOutput.articleDetail(
                article,
                authors: authors,
                preferText: preferText,
                maxContentLength: maxContentLength
            )
        )
    }

    static func handleSearchArticles(
        args: [String: Value],
        database: NNWDatabase
    ) throws -> CallTool.Result {
        let account = try database.resolveAccount(args["account"]?.stringValue)
        let query = try requireString(args, key: "query")
        let limit = resolveLimit(args, default: 50)

        let articles = try database.searchArticles(account: account, query: query, limit: limit)
        return result(
            Formatters.formatArticleTable(articles, title: "# Search Results: \"\(query)\"\n"),
            structured: StructuredOutput.articleList(articles)
        )
    }

    static func handleGetArticleCount(
        args: [String: Value],
        database: NNWDatabase
    ) throws -> CallTool.Result {
        let account = try database.resolveAccount(args["account"]?.stringValue)
        let (total, starred, unread) = try database.articleCounts(account: account)
        return result(
            Formatters.formatCounts(account: account.name, total: total, starred: starred, unread: unread),
            structured: StructuredOutput.counts(account: account.name, total: total, starred: starred, unread: unread)
        )
    }
}
