// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginPluginManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginPluginManager",
            targets: ["PluginPluginManager"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderSettingView"),
    ],
    targets: [
        .target(
            name: "PluginPluginManager",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
            ],
            path: "Sources/PluginPluginManager"
        ),
        .testTarget(
            name: "PluginPluginManagerTests",
            dependencies: [
                "PluginPluginManager",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
            ],
            path: "Tests/PluginPluginManagerTests"
        )
    ]
)
