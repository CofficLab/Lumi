// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppStoreConnect",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "PluginAppStoreConnect",
            targets: ["PluginAppStoreConnect"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.4.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitAppStorePromo"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderChatSection"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderSkill"),
        .package(path: "../ProviderAgentRules"),
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
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderNetwork", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderSkill", package: "ProviderSkill"),
                .product(name: "ProviderAgentRules", package: "ProviderAgentRules"),
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
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderSkill", package: "ProviderSkill"),
                .product(name: "ProviderAgentRules", package: "ProviderAgentRules"),
            ],
            path: "Tests/PluginAppStoreConnectTests"
        ),
    ]
)
