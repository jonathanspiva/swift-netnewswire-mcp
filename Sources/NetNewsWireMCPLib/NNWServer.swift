import Foundation
import MCP

public func startServer(database: NNWDatabase) async throws {
    let server = Server(
        name: "netnewswire-mcp",
        version: "1.0.0",
        capabilities: .init(tools: .init(listChanged: false))
    )

    let transport = StdioTransport()
    try await server.start(transport: transport)

    await server.withMethodHandler(ListTools.self) { _ in
        ListTools.Result(tools: ToolHandlers.allTools)
    }

    await server.withMethodHandler(CallTool.self) { params in
        ToolHandlers.handleCall(
            name: params.name,
            arguments: params.arguments,
            database: database
        )
    }

    log("NetNewsWire MCP server started")
    await server.waitUntilCompleted()
}

/// Log to stderr (stdout is reserved for JSON-RPC protocol)
public func log(_ message: String) {
    FileHandle.standardError.write(Data("[netnewswire-mcp] \(message)\n".utf8))
}
