// swift-tools-version: 6.0
import PackageDescription

/// Lumi 外部 HTTP API 基础层。
///
/// - **Agent Tool → HTTP 桥接**：把内核已注册的 Agent Tool 暴露为 HTTP 端点，
///   让外部调用方（IDE 插件、脚本、网页控制台）能用统一方式触达 Lumi 的
///   几乎所有能力，而不必为每个工具手写一个 HTTP 端点。
/// - **核心控制面**：服务状态、插件启停、会话与消息的查询与操作。
let package = Package(
    name: "KitWebAPI",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "KitWebAPI",
            targets: ["KitWebAPI"]
        ),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderWebServer"),
    ],
    targets: [
        .target(
            name: "KitWebAPI",
            dependencies: [
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderWebServer", package: "ProviderWebServer"),
                .product(name: "ProviderPluginControl", package: "LumiProviders"),
                .product(name: "ProviderPluginManaging", package: "LumiProviders"),
            ],
            path: "Sources/KitWebAPI"
        ),
        .testTarget(
            name: "KitWebAPITests",
            dependencies: ["KitWebAPI"],
            path: "Tests/KitWebAPITests"
        ),
    ]
)
