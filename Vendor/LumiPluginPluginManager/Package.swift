// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginPluginManager",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginPluginManager",
            targets: ["PluginPluginManager"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiProviders"),
        .package(path: "../LumiLogging"),
        .package(path: "../LumiKernel"),
        .package(path: "../LumiUI"),
        .package(path: "../LumiSettings"),
        .package(path: "../LumiLocalization"),
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
                .product(name: "ProviderPromptSuggestion", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginPluginManager",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginPluginManagerTests",
            dependencies: [
                "PluginPluginManager",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPromptSuggestion", package: "LumiProviders"),
                .product(name: "ProviderPluginManaging", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
            ],
            path: "Tests/PluginPluginManagerTests"
        ),
    ]
)
