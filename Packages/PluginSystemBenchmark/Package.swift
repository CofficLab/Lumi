// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSystemBenchmark",
    defaultLocalization: "en",
    platforms: [.macOS("14.0")],
    products: [
        .library(name: "PluginSystemBenchmark", targets: ["PluginSystemBenchmark"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0")
    ],
    targets: [
        .target(
            name: "PluginSystemBenchmark",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginSystemBenchmarkTests",
            dependencies: ["PluginSystemBenchmark"]
        ),
    ]
)
