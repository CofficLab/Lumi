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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderSettingView"),
    ],
    targets: [
        .target(
            name: "PluginSystemBenchmark",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginSystemBenchmarkTests",
            dependencies: ["PluginSystemBenchmark"]
        ),
    ]
)
