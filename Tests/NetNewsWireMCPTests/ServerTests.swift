import Foundation
import Testing
import MCP
@testable import NetNewsWireMCPLib

// MARK: - Protocol-level tests
//
// These drive the real server (`makeServer`) with an MCP `Client` over the SDK's
// in-memory transport, so they cover the initialize handshake, handler
// registration, and JSON-RPC encoding, not just the handler functions.

/// Connects a client to a fresh server, runs `body`, then tears both down.
private func withConnectedClient(
    database: Result<NNWDatabase, any Error>,
    _ body: (Client, Initialize.Result) async throws -> Void
) async throws {
    let server = await makeServer(database: database)
    let client = Client(name: "netnewswire-tests", version: "1.0.0")
    let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
    try await server.start(transport: serverTransport)
    let initResult = try await client.connect(transport: clientTransport)
    do {
        try await body(client, initResult)
    } catch {
        await client.disconnect()
        await server.stop()
        throw error
    }
    await client.disconnect()
    await server.stop()
}

/// Calls a tool and returns the full result (the SDK's convenience overload
/// drops `structuredContent`).
private func call(_ client: Client, _ name: String, _ arguments: [String: Value]? = nil) async throws -> CallTool.Result {
    try await client.send(CallTool.request(.init(name: name, arguments: arguments))).value
}

private func text(of result: CallTool.Result) -> String? {
    if case .text(let text, _, _)? = result.content.first { return text }
    return nil
}

@Suite struct `Initialize handshake` {
    @Test func `advertises server info, instructions, and latest protocol`() async throws {
        try await withFixture { _, db in
            try await withConnectedClient(database: .success(db)) { _, initResult in
                #expect(initResult.protocolVersion == Version.latest)
                #expect(initResult.serverInfo.name == "netnewswire-mcp")
                #expect(initResult.serverInfo.title == "NetNewsWire")
                #expect(initResult.serverInfo.version == serverVersion)
                #expect(initResult.capabilities.tools?.listChanged == false)
                let instructions = try #require(initResult.instructions)
                #expect(instructions.contains("read-only"))
                #expect(instructions.contains("list_feeds"))
            }
        }
    }
}

@Suite struct `Tool listing` {
    @Test func `lists every tool, all annotated read-only and closed-world`() async throws {
        try await withFixture { _, db in
            try await withConnectedClient(database: .success(db)) { client, _ in
                let (tools, cursor) = try await client.listTools()
                #expect(cursor == nil)
                #expect(tools.map(\.name) == ToolHandlers.allTools.map(\.name))
                #expect(tools.count == 7)
                for tool in tools {
                    #expect(tool.title?.isEmpty == false, "\(tool.name) has no title")
                    #expect(tool.description?.isEmpty == false, "\(tool.name) has no description")
                    #expect(tool.annotations.readOnlyHint == true, "\(tool.name)")
                    #expect(tool.annotations.destructiveHint == false, "\(tool.name)")
                    #expect(tool.annotations.openWorldHint == false, "\(tool.name)")
                    #expect(tool.inputSchema.objectValue?["type"] == .string("object"), "\(tool.name)")
                    #expect(tool.outputSchema?.objectValue?["type"] == .string("object"), "\(tool.name)")
                }
            }
        }
    }

    @Test func `required inputs are declared as properties`() {
        for tool in ToolHandlers.allTools {
            let schema = tool.inputSchema.objectValue ?? [:]
            let properties = schema["properties"]?.objectValue ?? [:]
            let required = schema["required"]?.arrayValue?.compactMap(\.stringValue) ?? []
            for name in required {
                #expect(properties[name] != nil, "\(tool.name) requires undeclared '\(name)'")
            }
        }
    }
}

@Suite struct `Structured output contract` {
    /// One successful call per tool against the fixture.
    static let calls: [(String, [String: Value])] = [
        ("list_accounts", [:]),
        ("list_feeds", ["account": "2_iCloud"]),
        ("list_starred_articles", ["account": "2_iCloud"]),
        ("list_recent_articles", ["account": "2_iCloud", "limit": 2]),
        ("get_article", ["account": "2_iCloud", "article_id": "a1"]),
        ("get_article", ["account": "2_iCloud", "article_id": "a3", "format": "text"]),
        ("search_articles", ["account": "2_iCloud", "query": "swift"]),
        ("get_article_count", ["account": "2_iCloud"]),
    ]

    @Test(arguments: calls)
    func `structuredContent matches the declared outputSchema`(name: String, arguments: [String: Value]) async throws {
        try await withFixture { _, db in
            try await withConnectedClient(database: .success(db)) { client, _ in
                let result = try await call(client, name, arguments)
                #expect(result.isError != true, "\(name): \(text(of: result) ?? "")")
                let structured = try #require(result.structuredContent, "\(name) returned no structuredContent")
                let tool = try #require(ToolHandlers.allTools.first { $0.name == name })
                let schema = try #require(tool.outputSchema)
                let violations = SchemaCheck.violations(of: structured, against: schema)
                #expect(violations.isEmpty, "\(name): \(violations.joined(separator: "; "))")
                #expect(text(of: result)?.isEmpty == false, "\(name) has no text content")
            }
        }
    }
}

@Suite struct `Tool calls over the protocol` {
    @Test func `unknown tool returns an error result, not a protocol failure`() async throws {
        try await withFixture { _, db in
            try await withConnectedClient(database: .success(db)) { client, _ in
                let result = try await call(client, "nonexistent_tool")
                #expect(result.isError == true)
                #expect(text(of: result)?.contains("Unknown tool") == true)
            }
        }
    }

    @Test func `missing required argument is reported to the model`() async throws {
        try await withFixture { _, db in
            try await withConnectedClient(database: .success(db)) { client, _ in
                let result = try await call(client, "get_article", ["account": "2_iCloud"])
                #expect(result.isError == true)
                #expect(text(of: result)?.contains("article_id") == true)
            }
        }
    }

    @Test func `startup failure still lists tools and explains Full Disk Access`() async throws {
        let failure: Result<NNWDatabase, any Error> = .failure(NNWError.accountsNotFound("/nowhere"))
        try await withConnectedClient(database: failure) { client, _ in
            let (tools, _) = try await client.listTools()
            #expect(tools.count == ToolHandlers.allTools.count)
            for tool in tools {
                let result = try await call(client, tool.name)
                #expect(result.isError == true, "\(tool.name)")
                #expect(text(of: result)?.contains("Full Disk Access") == true, "\(tool.name)")
            }
        }
    }
}

// MARK: - Minimal JSON Schema checker
//
// Covers the subset the output schemas use: `type` (single or array, incl.
// "null"), `properties`, `required`, and `items`. Enough to catch a handler
// that drifts from its declared schema, which strict clients reject.

enum SchemaCheck {
    static func violations(of value: Value, against schema: Value, path: String = "$") -> [String] {
        guard let schema = schema.objectValue else { return [] }
        var problems: [String] = []

        if let typeSpec = schema["type"] {
            let allowed = typeSpec.arrayValue?.compactMap(\.stringValue) ?? [typeSpec.stringValue].compactMap { $0 }
            if !allowed.contains(where: { matches(value, type: $0) }) {
                return ["\(path): expected \(allowed.joined(separator: "|")), got \(describe(value))"]
            }
        }

        if case .object(let object) = value {
            for key in schema["required"]?.arrayValue?.compactMap(\.stringValue) ?? [] where object[key] == nil {
                problems.append("\(path): missing required '\(key)'")
            }
            for (key, subschema) in schema["properties"]?.objectValue ?? [:] {
                if let child = object[key] {
                    problems += violations(of: child, against: subschema, path: "\(path).\(key)")
                }
            }
        }

        if case .array(let items) = value, let itemSchema = schema["items"] {
            for (index, item) in items.enumerated() {
                problems += violations(of: item, against: itemSchema, path: "\(path)[\(index)]")
            }
        }
        return problems
    }

    private static func matches(_ value: Value, type: String) -> Bool {
        switch (type, value) {
        case ("object", .object), ("array", .array), ("string", .string),
             ("boolean", .bool), ("null", .null), ("integer", .int), ("number", .int), ("number", .double):
            true
        case ("integer", .double(let d)):
            d == d.rounded()
        default:
            false
        }
    }

    private static func describe(_ value: Value) -> String {
        switch value {
        case .object: "object"
        case .array: "array"
        case .string: "string"
        case .bool: "boolean"
        case .null: "null"
        case .int: "integer"
        case .double: "number"
        case .data: "data"
        }
    }
}

@Suite struct `Schema checker` {
    let schema: Value = .object([
        "type": "object",
        "required": ["id"],
        "properties": .object([
            "id": .object(["type": "string"]),
            "count": .object(["type": .array(["integer", "null"])]),
            "tags": .object(["type": "array", "items": .object(["type": "string"])]),
        ]),
    ])

    @Test func `accepts a conforming value`() {
        let value: Value = .object(["id": "x", "count": .null, "tags": ["a", "b"]])
        #expect(SchemaCheck.violations(of: value, against: schema).isEmpty)
    }

    @Test func `flags missing required, wrong types, and bad array items`() {
        let value: Value = .object(["count": "three", "tags": ["a", 1]])
        let problems = SchemaCheck.violations(of: value, against: schema)
        #expect(problems.contains { $0.contains("missing required 'id'") })
        #expect(problems.contains { $0.contains("$.count") })
        #expect(problems.contains { $0.contains("$.tags[1]") })
    }
}
