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
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginShowImage",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderNetwork", package: "LumiProviders"),
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
