// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "netnewswire-mcp",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "netnewswire-mcp", targets: ["netnewswire-mcp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.10.0"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "NetNewsWireMCPLib",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/NetNewsWireMCPLib"
        ),
        .executableTarget(
            name: "netnewswire-mcp",
            dependencies: ["NetNewsWireMCPLib"],
            path: "Sources/netnewswire-mcp"
        ),
        .testTarget(
            name: "NetNewsWireMCPTests",
            dependencies: [
                "NetNewsWireMCPLib",
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
    ]
)
