// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationExport",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationExport", targets: ["PluginConversationExport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderToast"),
    ],
    targets: [
        .target(
            name: "PluginConversationExport",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitLocalization",
                "KitSuperLog",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessage",
                "ProviderToast",
            ],
            path: "Sources/PluginConversationExport",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationExportTests",
            dependencies: [
                "PluginConversationExport",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Tests/PluginConversationExportTests"
        ),
    ]
)
