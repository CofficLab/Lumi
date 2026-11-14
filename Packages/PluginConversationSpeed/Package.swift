// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationSpeed",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationSpeed", targets: ["PluginConversationSpeed"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginConversationSpeed",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessage",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginConversationSpeed",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationSpeedTests",
            dependencies: ["PluginConversationSpeed"],
            path: "Tests/PluginConversationSpeedTests"
        ),
    ]
)
