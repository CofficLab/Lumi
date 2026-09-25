// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSystemBenchmark",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginSystemBenchmark", targets: ["PluginSystemBenchmark"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderToolbar"),
    ],
    targets: [
        .target(
            name: "PluginSystemBenchmark",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginSystemBenchmarkTests",
            dependencies: ["PluginSystemBenchmark"]
        ),
    ]
)
