// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderMiniMax",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderMiniMax", targets: ["PluginLLMProviderMiniMax"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.12.0"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../KitLLM"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.11.1"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderMiniMax",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                "ProviderChatSection",
                "ProviderConversation",
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
            ],
            path: "Sources/PluginLLMProviderMiniMax",
            resources: [
                .process("../../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "PluginLLMProviderMiniMaxTests",
            dependencies: [
                "PluginLLMProviderMiniMax",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                "ProviderConversation",
            ],
            path: "Tests/PluginLLMProviderMiniMaxTests"
        ),
    ]
)
