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
        .package(path: "../SuperLogKit"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MCPKit",
            dependencies: [
                "HttpKit",
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "MCPKitTests",
            dependencies: ["MCPKit"],
            path: "Tests"
        ),
    ]
)
