// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppStorePromoDesigner",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginAppStorePromoDesigner", targets: ["PluginAppStorePromoDesigner"]),
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../AppStorePromoKit"),
        .package(path: "../HTMLPreviewKit"),
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRuntime"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginAppStorePromoDesigner",
            dependencies: [
                "AgentToolKit",
                "AppStorePromoKit",
                "HTMLPreviewKit",
                "KernelCore",
                "LocalizationKit",
                "LumiUI",
                "ProviderActivityBar",
                "ProviderContentView",
                "ProviderDocsView",
                "ProviderProject",
                "ProviderRailView",
                "ProviderStorage",
                "ProviderToolManager",
                .product(name: "ProviderConversationInput", package: "ProviderRuntime"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginAppStorePromoDesignerTests",
            dependencies: [
                "PluginAppStorePromoDesigner",
                "AgentToolKit",
                "AppStorePromoKit",
                "KernelCore",
                "ProviderStorage",
            ]
        ),
    ]
)
