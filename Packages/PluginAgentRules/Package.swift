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
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../KitAgentTool"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiSettings"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderLLMContext"),
        .package(path: "../KitLLM"),
        .package(path: "../KitTestSupport"),
    ],
    targets: [
        .target(
            name: "PluginAgentRules",
            dependencies: [
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                "ProviderToolManager",
                "ProviderChatSection",
                .product(name: "ProviderAgentRules", package: "LumiProviders"),
                "ProviderLifecycleHooks",
                "ProviderLLMContext",
                "KitLLM",
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginAgentRulesTests",
            dependencies: [
                "PluginAgentRules",
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderAgentRules", package: "LumiProviders"),
                "KitLLM",
                "ProviderLifecycleHooks",
                "ProviderLLMContext",
                .product(name: "KitTestSupport", package: "KitTestSupport"),
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ]
        ),
    ]
)
