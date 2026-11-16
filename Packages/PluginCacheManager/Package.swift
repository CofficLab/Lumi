// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCacheManager",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginCacheManager",
            targets: ["PluginCacheManager"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.25.0"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginCacheManager",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDiskCache", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginCacheManager",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginCacheManagerTests",
            dependencies: [
                "PluginCacheManager",
                .product(name: "ProviderDiskCache", package: "LumiProviders"),
            ]
        )
    ]
)