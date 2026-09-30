import Foundation
public import MCP

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
                return errorResult("Unknown tool: \(name)")
            }
        } catch let error as NNWError {
            // NNWError messages are already user-facing and safe.
            return errorResult(error.description)
        } catch {
            // Log the raw error (e.g. a GRDB error carrying the DB file path) to
            // stderr; return a friendly message so internals don't leak to the client.
            log("Tool '\(name)' failed: \(error)")
            return errorResult(friendlyMessage(for: name))
        }
    }

    /// Result for every tool call when the databases couldn't be opened at startup.
    /// The server stays up so the client shows this instead of a bare disconnect.
    public static func startupFailureResult(_ error: any Error) -> CallTool.Result {
        errorResult(startupFailureMessage(error))
    }

    /// Actionable message for a startup failure. Most often this is macOS privacy
    /// protection (TCC) blocking the NetNewsWire container, which surfaces as a
    /// missing directory or "Operation not permitted".
    static func startupFailureMessage(_ error: any Error) -> String {
        let reason = (error as? NNWError)?.description ?? "The NetNewsWire databases could not be read."
        return """
            \(reason)

            If NetNewsWire is installed, the app that launched this server needs Full Disk Access: \
            System Settings → Privacy & Security → Full Disk Access, enable Claude (desktop app) \
            or your terminal (Claude Code), then restart that app.
            """
    }

    private static func errorResult(_ message: String) -> CallTool.Result {
        CallTool.Result(
            content: [.text(text: message, annotations: nil, _meta: nil)],
            isError: true
        )
    }

    /// Non-leaking, actionable message for an unexpected (non-NNWError) failure.
    private static func friendlyMessage(for tool: String) -> String {
        switch tool {
        case "search_articles":
            return "Search failed. Check the query syntax (FTS4: words, \"quoted phrases\", OR, NOT) and try again."
        default:
            return "The '\(tool)' request could not be completed. The NetNewsWire database may be unavailable or in an unexpected state."
        }
    }

    // MARK: - Parameter Helpers

    static func requireString(_ args: [String: Value], key: String) throws -> String {
        guard let value = args[key]?.stringValue else {
            throw NNWError.missingParameter(key)
        }
        return value
    }

    /// Largest number of rows any query will return.
    static let maxLimit = 500

    /// Read an optional integer argument, accepting JSON numbers that arrive as
    /// either integers or integral doubles (e.g. `50` or `50.0`).
    static func optionalInt(_ args: [String: Value], key: String) -> Int? {
        guard let value = args[key] else { return nil }
        if let i = value.intValue { return i }
        if let d = value.doubleValue, d == d.rounded() { return Int(d) }
        return nil
    }

    /// Resolve and clamp a `limit` argument into `1...maxLimit`, falling back to
    /// `defaultValue` when absent or non-numeric. Prevents a negative limit
    /// (which SQLite treats as "no limit") or a huge value from dumping the
    /// entire table into a response.
    static func resolveLimit(_ args: [String: Value], default defaultValue: Int) -> Int {
        let raw = optionalInt(args, key: "limit") ?? defaultValue
        return min(max(raw, 1), maxLimit)
    }

    /// Default and maximum article-body length returned by `get_article`.
    static let defaultContentLength = 50_000
    static let maxContentLength = 200_000

    /// Resolve and clamp the `max_content_length` argument into
    /// `100...maxContentLength`, so `get_article` can't return an unbounded body
    /// (which would flood the client's context window).
    static func resolveContentLength(_ args: [String: Value]) -> Int {
        let raw = optionalInt(args, key: "max_content_length") ?? defaultContentLength
        return min(max(raw, 100), maxContentLength)
    }
}
