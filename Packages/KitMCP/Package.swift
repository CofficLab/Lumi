// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitMCP",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "KitMCP",
            targets: ["KitMCP"]
        )
    ],
    dependencies: [
        // 官方 MCP Swift SDK。官方分级 Tier 3（实验性），锁精确版本，
        // 对外仅暴露 KitMCP 自有类型（MCPServerServing / MCPToolDescriptor 等），
        // 后续替换实现不影响调用方。
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.1"),
    ],
    targets: [
        .target(
            name: "KitMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"]
        ),
        .testTarget(
            name: "KitMCPTests",
            dependencies: [
                "KitMCP",
                // 测试用 SDK 的 Server / InMemoryTransport 构造进程内 mock 服务器。
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Tests"
        )
    ]
)
