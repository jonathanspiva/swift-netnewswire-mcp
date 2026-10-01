import Foundation
import MCP

/// Guidance surfaced to the MCP client on `initialize`, so the model knows how
/// to drive the tools without reading the README.
let serverInstructions = """
    Read-only access to the local NetNewsWire RSS reader's SQLite databases.

    Usage notes:
    - Feed IDs are the feed's XML URL (e.g. "https://swift.org/feed.xml"), not a UUID.
      Get them from `list_feeds`.
    - Article IDs come from `list_starred_articles`, `list_recent_articles`, or
      `search_articles`. Pass one to `get_article` for the full content.
    - `account` defaults to the first account; call `list_accounts` to see the options
      (typically "2_iCloud" and "OnMyMac").
    - Dates are Unix timestamps (seconds since 1970).
    - `search_articles` uses FTS4 syntax: words, "quoted phrases", OR, NOT.
    - Every tool is read-only; nothing is ever modified.
    """

public let serverVersion = "1.2.0"

/// Starts the stdio server. A `.failure` database (e.g. no Full Disk Access) still
/// starts the server: tools are listed, and each call returns an actionable error,
/// so the client can show the fix instead of a bare "server disconnected".
public func startServer(database: Result<NNWDatabase, any Error>) async throws {
    let server = await makeServer(database: database)
    try await server.start(transport: StdioTransport())

    log("NetNewsWire MCP server started")
    await server.waitUntilCompleted()
}

/// Builds a server with all handlers registered but not yet started, so tests
/// can drive it over an in-memory transport.
func makeServer(database: Result<NNWDatabase, any Error>) async -> Server {
    let server = Server(
        name: "netnewswire-mcp",
        version: serverVersion,
        title: "NetNewsWire",
        instructions: serverInstructions,
        capabilities: .init(tools: .init(listChanged: false))
    )

    // Register handlers BEFORE starting the transport. `server.start` spins up
    // the message-receive loop, so registering afterwards risks a client's
    // first `tools/list` / `tools/call` arriving before the handler exists.
    await server.withMethodHandler(ListTools.self) { _ in
        ListTools.Result(tools: ToolHandlers.allTools)
    }

    await server.withMethodHandler(CallTool.self) { params in
        switch database {
        case .success(let database):
            ToolHandlers.handleCall(
                name: params.name,
                arguments: params.arguments,
                database: database
            )
        case .failure(let error):
            ToolHandlers.startupFailureResult(error)
        }
    }

    return server
}

/// Log to stderr (stdout is reserved for JSON-RPC protocol)
public func log(_ message: String) {
    FileHandle.standardError.write(Data("[netnewswire-mcp] \(message)\n".utf8))
}
