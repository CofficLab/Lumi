// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToolLLMProvider",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginToolLLMProvider", targets: ["PluginToolLLMProvider"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.13.0"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.0"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderMessageRendering"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginToolLLMProvider",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiUI", package: "LumiUI"),
                "KitAgentTool",
                "KitLLM",
                "ProviderConversation",
                "ProviderLLMManager",
                "ProviderMessageRendering",
                "ProviderToolManager",
            ],
            path: "Sources/PluginToolLLMProvider",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginToolLLMProviderTests",
            dependencies: [
                "PluginToolLLMProvider",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "KitAgentTool",
                "KitLLM",
                "ProviderConversation",
                "ProviderLLMManager",
                "ProviderMessageRendering",
                "ProviderToolManager",
            ],
            path: "Tests/PluginToolLLMProviderTests"
        ),
    ]
)
