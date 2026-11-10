// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationVerbosity",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationVerbosity", targets: ["PluginConversationVerbosity"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiProviders")
    ],
    targets: [
        .target(
            name: "PluginConversationVerbosity",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "ProviderChatSection",
                "ProviderConversation",
                .product(name: "ProviderToast", package: "LumiProviders"),
                "LumiUI",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginConversationVerbosity",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationVerbosityTests",
            dependencies: [
                "PluginConversationVerbosity",
            ],
            path: "Tests/PluginConversationVerbosityTests"
        ),
    ]
)
