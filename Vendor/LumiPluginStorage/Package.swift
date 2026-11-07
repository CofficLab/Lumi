// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginStorage",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        // Keep the module/product name stable so existing projects can keep
        // using `import PluginStorage` during the migration.
        .library(name: "PluginStorage", targets: ["PluginStorage"])
    ],
    dependencies: [
        .package(path: "../LumiProviders"),
        .package(path: "../LumiLogging"),
        .package(path: "../LumiKernel")
    ],
    targets: [
        .target(
            name: "PluginStorage",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderStorage", package: "LumiProviders")
            ],
            path: "Sources/PluginStorage"
        ),
        .testTarget(
            name: "PluginStorageTests",
            dependencies: ["PluginStorage"]
        )
    ]
)
