// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToolbarSettings",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginToolbarSettings",
            targets: ["PluginToolbarSettings"]
        ),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiProviders")
    ],
    targets: [
        .target(
            name: "PluginToolbarSettings",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            path: "Sources/PluginToolbarSettings"
        ),
        .testTarget(
            name: "PluginToolbarSettingsTests",
            dependencies: ["PluginToolbarSettings"]
        )
    ]
)
