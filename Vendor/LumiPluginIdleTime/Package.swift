// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginIdleTime",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(
            name: "PluginIdleTime",
            targets: ["PluginIdleTime"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiLogging"),
        .package(path: "../LumiKernel"),
        .package(path: "../LumiLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../LumiProviders")
    ],
    targets: [
        .target(
            name: "PluginIdleTime",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderIdleTime", package: "LumiProviders"),
            ],
            path: "Sources/PluginIdleTime",
            resources: [
                .process("../../Resources")
            ]
        ),
        .testTarget(
            name: "PluginIdleTimeTests",
            dependencies: [
                "PluginIdleTime",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderIdleTime", package: "LumiProviders"),
            ],
            path: "Tests/PluginIdleTimeTests"
        )
    ]
)