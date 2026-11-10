// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageListChatGPT",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [.library(name: "PluginMessageListChatGPT", targets: ["PluginMessageListChatGPT"])],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
    ],
    targets: [
        .target(
            name: "PluginMessageListChatGPT",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginMessageListChatGPTTests",
            dependencies: [
                "PluginMessageListChatGPT",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
            ]
        ),
    ]
)
