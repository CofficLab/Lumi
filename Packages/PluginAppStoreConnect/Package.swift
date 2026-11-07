// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppStoreConnect",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(
            name: "PluginAppStoreConnect",
            targets: ["PluginAppStoreConnect"]
        ),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitAppStorePromo"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../../Vendor/LumiSettings"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitTestSupport"),
    ],
    targets: [
        .target(
            name: "PluginAppStoreConnect",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "KitAppStorePromo", package: "KitAppStorePromo"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderMessageRendering", package: "ProviderMessageRendering"),
                .product(name: "ProviderNetwork", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderSkill", package: "LumiProviders"),
                .product(name: "ProviderAgentRules", package: "LumiProviders"),
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ],
            resources: [
                .process("../../Resources/Localizable.xcstrings"),
                .copy("../../Resources/Skills"),
                .copy("../../Resources/AgentRules"),
            ],
            linkerSettings: [.linkedFramework("Security")]
        ),
        .testTarget(
            name: "PluginAppStoreConnectTests",
            dependencies: [
                "PluginAppStoreConnect",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderMessageRendering", package: "ProviderMessageRendering"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderSkill", package: "LumiProviders"),
                .product(name: "ProviderAgentRules", package: "LumiProviders"),
                .product(name: "KitTestSupport", package: "KitTestSupport"),
            ],
            path: "Tests/PluginAppStoreConnectTests"
        ),
    ]
)
