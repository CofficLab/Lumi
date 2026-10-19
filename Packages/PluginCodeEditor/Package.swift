// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCodeEditor",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginCodeEditor", targets: ["PluginCodeEditor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(path: "../PluginCodeEditorHost"),
        .package(path: "../ProviderEditor"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversationInputBlock"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.9.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
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
