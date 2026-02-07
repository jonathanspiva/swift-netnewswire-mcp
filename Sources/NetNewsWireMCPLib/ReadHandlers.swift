import Foundation
import MCP

// MARK: - Read Handler Implementations

extension ToolHandlers {

    static func handleListAccounts(database: NNWDatabase) -> CallTool.Result {
        let accounts = database.listAccounts()
        return CallTool.Result(content: [.text(Formatters.formatAccountList(accounts))])
    }

    static func handleListFeeds(
        args: [String: Value],
        database: NNWDatabase
    ) throws -> CallTool.Result {
        let account = try database.resolveAccount(args["account"]?.stringValue)
        let feeds = try database.listFeeds(account: account)
        return CallTool.Result(content: [.text(Formatters.formatFeedTable(feeds))])
    }

    static func handleListStarredArticles(
        args: [String: Value],
        database: NNWDatabase
    ) throws -> CallTool.Result {
        let account = try database.resolveAccount(args["account"]?.stringValue)
        let feedID = args["feed_id"]?.stringValue
        let limit = args["limit"]?.intValue ?? 100

        let articles = try database.starredArticles(account: account, feedID: feedID, limit: limit)
        return CallTool.Result(content: [.text(
            Formatters.formatArticleTable(articles, title: "# Starred Articles\n")
        )])
    }

    static func handleListRecentArticles(
        args: [String: Value],
        database: NNWDatabase
    ) throws -> CallTool.Result {
        let account = try database.resolveAccount(args["account"]?.stringValue)
        let feedID = args["feed_id"]?.stringValue
        let limit = args["limit"]?.intValue ?? 50
        let starredOnly = args["starred_only"]?.boolValue ?? false

        let articles = try database.recentArticles(
            account: account,
            feedID: feedID,
            limit: limit,
            starredOnly: starredOnly
        )
        let title = starredOnly ? "# Recent Starred Articles\n" : "# Recent Articles\n"
        return CallTool.Result(content: [.text(
            Formatters.formatArticleTable(articles, title: title)
        )])
    }

    static func handleGetArticle(
        args: [String: Value],
        database: NNWDatabase
    ) throws -> CallTool.Result {
        let account = try database.resolveAccount(args["account"]?.stringValue)
        let articleID = try requireString(args, key: "article_id")

        let (article, authors) = try database.getArticle(account: account, articleID: articleID)
        return CallTool.Result(content: [.text(
            Formatters.formatArticleDetail(article, authors: authors)
        )])
    }

    static func handleSearchArticles(
        args: [String: Value],
        database: NNWDatabase
    ) throws -> CallTool.Result {
        let account = try database.resolveAccount(args["account"]?.stringValue)
        let query = try requireString(args, key: "query")
        let limit = args["limit"]?.intValue ?? 50

        let articles = try database.searchArticles(account: account, query: query, limit: limit)
        return CallTool.Result(content: [.text(
            Formatters.formatArticleTable(articles, title: "# Search Results: \"\(query)\"\n")
        )])
    }

    static func handleGetArticleCount(
        args: [String: Value],
        database: NNWDatabase
    ) throws -> CallTool.Result {
        let account = try database.resolveAccount(args["account"]?.stringValue)
        let (total, starred, unread) = try database.articleCounts(account: account)
        return CallTool.Result(content: [.text(
            Formatters.formatCounts(account: account.name, total: total, starred: starred, unread: unread)
        )])
    }
}
