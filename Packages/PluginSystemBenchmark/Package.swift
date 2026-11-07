// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSystemBenchmark",
    defaultLocalization: "en",
    platforms: [.macOS("13.1")],
    products: [
        .library(name: "PluginSystemBenchmark", targets: ["PluginSystemBenchmark"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiSettings"),
        .package(path: "../../Vendor/LumiProviders")
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
