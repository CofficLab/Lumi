// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationBehavior",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationBehavior", targets: ["PluginConversationBehavior"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../KitLLM"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiProviders")
    ],
    targets: [
        .target(
            name: "PluginConversationBehavior",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderLifecycleHooks",
                "ProviderLLMManager",
                .product(name: "ProviderToast", package: "LumiProviders"),
                "LumiUI",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginConversationBehavior",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationBehaviorTests",
            dependencies: [
                "PluginConversationBehavior",
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderToast", package: "LumiProviders"),
            ],
            path: "Tests/PluginConversationBehaviorTests"
        ),
    ]
)
