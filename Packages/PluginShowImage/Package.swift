// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginShowImage",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginShowImage",
            targets: ["PluginShowImage"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
        .package(path: "../AgentToolKit"),
        .package(path: "../ProviderNetwork"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginShowImage",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "ProviderNetwork", package: "ProviderNetwork"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Sources/PluginShowImage"
        ),
        .testTarget(
            name: "PluginShowImageTests",
            dependencies: ["PluginShowImage"]
        )
    ]
)
