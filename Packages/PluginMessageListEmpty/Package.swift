// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageListEmpty",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginMessageListEmpty", targets: ["PluginMessageListEmpty"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.11.1"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../KitProjectDetect"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderGit"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderProjectRAG"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.13.0")
    ],
    targets: [
        .target(
            name: "PluginMessageListEmpty",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitProjectDetect", package: "KitProjectDetect"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderGit", package: "ProviderGit"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderProjectRAG", package: "ProviderProjectRAG"),
                .product(name: "ProviderPromptSuggestion", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginMessageListEmptyTests",
            dependencies: [
                "PluginMessageListEmpty",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderGit", package: "ProviderGit"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderProjectRAG", package: "ProviderProjectRAG"),
                .product(name: "ProviderPromptSuggestion", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ]
        ),
    ]
)
