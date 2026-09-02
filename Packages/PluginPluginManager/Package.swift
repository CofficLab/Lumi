// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginPluginManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginPluginManager",
            targets: ["PluginPluginManager"]
        ),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KernelCore"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderPluginManaging"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderPromptSuggestion"),
    ],
    targets: [
        .target(
            name: "PluginPluginManager",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderPluginManaging", package: "ProviderPluginManaging"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderPromptSuggestion", package: "ProviderPromptSuggestion"),
            ],
            path: "Sources/PluginPluginManager"
        ),
        .testTarget(
            name: "PluginPluginManagerTests",
            dependencies: [
                "PluginPluginManager",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderPromptSuggestion", package: "ProviderPromptSuggestion"),
                .product(name: "ProviderPluginManaging", package: "ProviderPluginManaging"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
            ],
            path: "Tests/PluginPluginManagerTests"
        )
    ]
)
