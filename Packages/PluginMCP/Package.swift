// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMCP",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginMCP", targets: ["PluginMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../KitMCP"),
        .package(path: "../ProviderMCP"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        // 测试 target 需要直接构造 mock MCP Server（与 KitMCP 同版本，保证类型一致）。
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.1"),
    ],
    targets: [
        .target(
            name: "PluginMCP",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "KitMCP", package: "KitMCP"),
                .product(name: "ProviderMCP", package: "ProviderMCP"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginMCP",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginMCPTests",
            dependencies: [
                "PluginMCP",
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Tests/PluginMCPTests"
        ),
    ]
)
