// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageListEmpty",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginMessageListEmpty", targets: ["PluginMessageListEmpty"])],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderPromptSuggestion"),
        .package(path: "../ProviderToolbar"),
    ],
    targets: [
        .target(
            name: "PluginMessageListEmpty",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderPromptSuggestion", package: "ProviderPromptSuggestion"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
    ]
)
