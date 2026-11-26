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
        .package(url: "https://github.com/lumi-softworks/LumiPluginDevice.git", from: "1.3.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.18.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.4"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessage.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessageRendering.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginDeviceChat",
            dependencies: [
                .product(name: "PluginDevice", package: "LumiPluginDevice"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
                .product(name: "ProviderMessageRendering", package: "LumiProviderMessageRendering"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
            ]
        ),
        .testTarget(
            name: "PluginDeviceChatTests",
            dependencies: [
                "PluginDeviceChat",
                .product(name: "PluginDevice", package: "LumiPluginDevice"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
                .product(name: "ProviderMessageRendering", package: "LumiProviderMessageRendering"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
            ]
        ),
    ]
)
