// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationExport",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationExport", targets: ["PluginConversationExport"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../../Vendor/LumiProviders")
    ],
    targets: [
        .target(
            name: "PluginConversationExport",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessage",
                .product(name: "ProviderToast", package: "LumiProviders"),
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
