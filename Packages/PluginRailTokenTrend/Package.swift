// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginRailTokenTrend",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginRailTokenTrend", targets: ["PluginRailTokenTrend"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(path: "../ProviderMessage"),
    ],
    targets: [
        .target(
            name: "PluginRailTokenTrend",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginRailTokenTrendTests",
            dependencies: [
                "PluginRailTokenTrend",
            ]
        ),
    ]
)
