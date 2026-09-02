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
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderNetwork"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginShowImage",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
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
