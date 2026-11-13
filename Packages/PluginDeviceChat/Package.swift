// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDeviceChat",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginDeviceChat",
            targets: ["PluginDeviceChat"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiPluginDevice.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
    ],
    targets: [
        .target(
            name: "PluginDeviceChat",
            dependencies: [
                .product(name: "PluginDevice", package: "LumiPluginDevice"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "KitAgentTool",
                "ProviderMessage",
                "ProviderMessageRendering",
                "ProviderToolManager",
            ]
        ),
        .testTarget(
            name: "PluginDeviceChatTests",
            dependencies: [
                "PluginDeviceChat",
                .product(name: "PluginDevice", package: "LumiPluginDevice"),
                "KitAgentTool",
                "ProviderMessage",
                "ProviderMessageRendering",
                "ProviderToolManager",
            ]
        ),
    ]
)
