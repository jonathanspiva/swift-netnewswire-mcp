// swift-tools-version:6.4
import PackageDescription

/// Opt in to every upcoming language feature the 6.4 compiler offers (beyond
/// what Swift 6 mode already enables), plus strict memory safety checking.
let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
    .strictMemorySafety(),
]

let package = Package(
    name: "netnewswire-mcp",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "netnewswire-mcp", targets: ["netnewswire-mcp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.12.1"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.11.0"),
    ],
    targets: [
        .target(
            name: "NetNewsWireMCPLib",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/NetNewsWireMCPLib",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "netnewswire-mcp",
            dependencies: ["NetNewsWireMCPLib"],
            path: "Sources/netnewswire-mcp",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "NetNewsWireMCPTests",
            dependencies: [
                "NetNewsWireMCPLib",
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)
