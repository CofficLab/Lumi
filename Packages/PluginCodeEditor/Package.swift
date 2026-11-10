// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCodeEditor",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "PluginCodeEditor", targets: ["PluginCodeEditor"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../PluginCodeEditorHost"),
        .package(path: "../ProviderEditor"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversationInputBlock"),
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginCodeEditor",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderEditor", package: "ProviderEditor"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderConversationInput", package: "LumiProviders"),
                "ProviderConversationInputBlock",
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderTheme", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("../../Resources")]
        ),
        .testTarget(
            name: "PluginCodeEditorTests",
            dependencies: [
                "PluginCodeEditor",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderEditor", package: "ProviderEditor"),
                .product(name: "PluginCodeEditorHost", package: "PluginCodeEditorHost"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderConversationInput", package: "LumiProviders"),
                "ProviderConversationInputBlock",
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderPluginControl", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderTheme", package: "LumiProviders"),
            ]
        ),
    ]
)
