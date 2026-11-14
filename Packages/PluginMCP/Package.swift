// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMCP",
    defaultLocalization: "en",
    platforms: [.macOS("14.0")],
    products: [
        .library(name: "PluginMCP", targets: ["PluginMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.1"),
        .package(path: "../KitMCP"),
        // 工具 schema 的规范化文本契约（`NormalizedSchemaProviding`）：
        // MCP 工具在注册时就解析好了 schema，把它交给 AgentLoop 的 token
        // 估算即可省掉每个请求的「解析→再序列化」往返（Issue #1275）。
        .package(path: "../KitLLM"),
        .package(path: "../ProviderMCP"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        // 测试 target 需要直接构造 mock MCP Server（与 KitMCP 同版本，保证类型一致）。
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.1"),
        .package(path: "../KitTestSupport"),
    ],
    targets: [
        .target(
            name: "PluginMCP",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "KitMCP", package: "KitMCP"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderMCP", package: "ProviderMCP"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ],
            path: "Sources/PluginMCP",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginMCPTests",
            dependencies: [
                "PluginMCP",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "ProviderMCP", package: "ProviderMCP"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "KitTestSupport", package: "KitTestSupport"),
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ],
            path: "Tests/PluginMCPTests"
        ),
    ]
)
