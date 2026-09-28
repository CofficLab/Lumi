// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginConversationNew",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginConversationNew", targets: ["PluginConversationNew"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderChatSection"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.2")
    ],
    targets: [
        .target(
            name: "PluginConversationNew",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationNewTests",
            dependencies: [
                "PluginConversationNew",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ]
        ),
    ]
)
