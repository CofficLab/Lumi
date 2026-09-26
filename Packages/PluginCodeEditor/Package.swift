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
        .package(path: "../KitSuperLog"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../PluginCodeEditorHost"),
        .package(path: "../ProviderEditor"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderConversationInput"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderPluginControl"),
        .package(path: "../ProviderTheme"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "PluginCodeEditor",
            dependencies: [
                "KitSuperLog",
                "KitLocalization",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderEditor", package: "ProviderEditor"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderConversationInput", package: "ProviderConversationInput"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderTheme", package: "ProviderTheme"),
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
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderConversationInput", package: "ProviderConversationInput"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderPluginControl", package: "ProviderPluginControl"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderTheme", package: "ProviderTheme"),
            ]
        ),
    ]
)
