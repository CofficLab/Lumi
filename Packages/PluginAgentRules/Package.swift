// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentRules",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginAgentRules", targets: ["PluginAgentRules"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.5"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.18.1"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderLifecycleHooks.git", from: "1.0.0"),
        .package(path: "../ProviderLLMContext"),
        .package(url: "https://github.com/lumi-softworks/LumiKitLLM.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiKitTestSupport.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginAgentRules",
            dependencies: [
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderAgentRules", package: "LumiProviders"),
                .product(name: "ProviderLifecycleHooks", package: "LumiProviderLifecycleHooks"),
                "ProviderLLMContext",
                .product(name: "KitLLM", package: "LumiKitLLM"),
                .product(name: "KitTestIsolation", package: "LumiKitTestSupport"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginAgentRulesTests",
            dependencies: [
                "PluginAgentRules",
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderAgentRules", package: "LumiProviders"),
                .product(name: "KitLLM", package: "LumiKitLLM"),
                .product(name: "ProviderLifecycleHooks", package: "LumiProviderLifecycleHooks"),
                "ProviderLLMContext",
                .product(name: "KitTestSupport", package: "LumiKitTestSupport"),
                .product(name: "KitTestIsolation", package: "LumiKitTestSupport"),
            ]
        ),
    ]
)
