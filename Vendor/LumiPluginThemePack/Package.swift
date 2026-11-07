// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginThemePack",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginThemePack",
            targets: ["PluginThemePack"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiThemePack"),
        .package(path: "../LumiKernel"),
        .package(path: "../LumiLogging"),
        .package(path: "../LumiUI"),
        .package(path: "../LumiProviders"),
        .package(path: "../LumiSettings"),
        .package(path: "../LumiLocalization"),
    ],
    targets: [
        .target(
            name: "PluginThemePack",
            dependencies: [
                .product(name: "LumiThemePack", package: "LumiThemePack"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderCommand", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderTheme", package: "LumiProviders"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginThemePack",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginThemePackTests",
            dependencies: ["PluginThemePack", .product(name: "LumiThemePack", package: "LumiThemePack")]
        )
    ]
)
