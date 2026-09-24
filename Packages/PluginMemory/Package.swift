// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMemory",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginMemory", targets: ["PluginMemory"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderSettingView"),
    ],
    targets: [
        .target(
            name: "PluginMemory",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitAgentTool",
                "KitLocalization",
                "LumiUI",
                "ProviderStorage",
                "ProviderToolManager",
                "ProviderProject",
                "ProviderSettingView",
            ],
            path: "Sources/PluginMemory"
        ),
        .testTarget(
            name: "PluginMemoryTests",
            dependencies: [
                "PluginMemory",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Tests/PluginMemoryTests"
        ),
    ]
)
