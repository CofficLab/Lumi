// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginActivityBar",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginActivityBar",
            targets: ["PluginActivityBar"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiProviders"),
        .package(path: "../LumiKernel"),
        .package(path: "../LumiUI"),
        .package(path: "../LumiLogging"),
    ],
    targets: [
        .target(
            name: "PluginActivityBar",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderPluginManaging", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
            ]
        ),
        .testTarget(
            name: "PluginActivityBarTests",
            dependencies: [
                "PluginActivityBar",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
            ]
        ),
    ]
)
