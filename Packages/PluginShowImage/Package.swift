// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginShowImage",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginShowImage",
            targets: ["PluginShowImage"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginShowImage",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderNetwork", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Sources/PluginShowImage",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginShowImageTests",
            dependencies: ["PluginShowImage"]
        )
    ]
)
