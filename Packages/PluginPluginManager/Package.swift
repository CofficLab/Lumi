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
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.7"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(path: "../ProviderPromptSuggestion"),
    ],
    targets: [
        .target(
            name: "PluginPluginManager",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderPluginManaging", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderPromptSuggestion", package: "ProviderPromptSuggestion"),
            ],
            path: "Sources/PluginPluginManager",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PluginPluginManagerTests",
            dependencies: [
                "PluginPluginManager",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPromptSuggestion", package: "ProviderPromptSuggestion"),
                .product(name: "ProviderPluginManaging", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
            ],
            path: "Tests/PluginPluginManagerTests"
        )
    ]
)
