// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCodeEditor",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginCodeEditor", targets: ["PluginCodeEditor"]),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KitLocalization"),
        .package(path: "../KernelCore"),
        .package(path: "../PluginCodeEditorHost"),
        .package(path: "../EditorContracts"),
        .package(path: "../EditorService"),
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
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginCodeEditor",
            dependencies: [
                "KitSuperLog",
                "KitLocalization",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
                .product(name: "EditorService", package: "EditorService"),
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
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("../../Resources")]
        ),
        .testTarget(
            name: "PluginCodeEditorTests",
            dependencies: [
                "PluginCodeEditor",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorContracts", package: "EditorContracts"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "PluginCodeEditorHost", package: "PluginCodeEditorHost"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderConversationInput", package: "ProviderConversationInput"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderPluginControl", package: "ProviderPluginControl"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
            ]
        ),
    ]
)
