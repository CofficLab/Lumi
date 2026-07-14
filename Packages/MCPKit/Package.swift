// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MCPKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "MCPKit",
            targets: ["MCPKit"]
        ),
    ],
    dependencies: [
        .package(path: "../HttpKit"),
        .package(path: "../LumiLocalizationKit"),
        .package(path: "../SuperLogKit"),
        .package(path: "../LumiLocalizationKit"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MCPKit",
            dependencies: [
                "HttpKit",
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "MCPKitTests",
            dependencies: ["MCPKit"],
            path: "Tests"
        ),
    ]
)
