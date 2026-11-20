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
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.18.1"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.4"),
        .package(url: "https://github.com/lumi-softworks/LumiKitLLM.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderLLMManager.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessageRendering.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginToolLLMProvider",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "KitLLM", package: "LumiKitLLM"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderLLMManager", package: "LumiProviderLLMManager"),
                .product(name: "ProviderMessageRendering", package: "LumiProviderMessageRendering"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
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
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "KitLLM", package: "LumiKitLLM"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderLLMManager", package: "LumiProviderLLMManager"),
                .product(name: "ProviderMessageRendering", package: "LumiProviderMessageRendering"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
            ],
            path: "Tests/PluginToolLLMProviderTests"
        ),
    ]
)
