import Foundation
import MCP

public enum ToolHandlers {

    // MARK: - All Tools

    public static let allTools: [Tool] = [
        listAccountsTool,
        listFeedsTool,
        listStarredArticlesTool,
        listRecentArticlesTool,
        getArticleTool,
        searchArticlesTool,
        getArticleCountTool,
    ]

    // MARK: - Call Routing

    public static func handleCall(
        name: String,
        arguments: [String: Value]?,
        database: NNWDatabase
    ) -> CallTool.Result {
        do {
            let args = arguments ?? [:]
            switch name {
            case "list_accounts":
                return handleListAccounts(database: database)
            case "list_feeds":
                return try handleListFeeds(args: args, database: database)
            case "list_starred_articles":
                return try handleListStarredArticles(args: args, database: database)
            case "list_recent_articles":
                return try handleListRecentArticles(args: args, database: database)
            case "get_article":
                return try handleGetArticle(args: args, database: database)
            case "search_articles":
                return try handleSearchArticles(args: args, database: database)
            case "get_article_count":
                return try handleGetArticleCount(args: args, database: database)
            default:
                return CallTool.Result(
                    content: [.text("Unknown tool: \(name)")],
                    isError: true
                )
            }
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error)")],
                isError: true
            )
        }
    }

    // MARK: - Parameter Helpers

    static func requireString(_ args: [String: Value], key: String) throws -> String {
        guard let value = args[key]?.stringValue else {
            throw NNWError.missingParameter(key)
        }
        return value
    }
}
