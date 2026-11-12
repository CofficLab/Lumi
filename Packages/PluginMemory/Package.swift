// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMemory",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginMemory", targets: ["PluginMemory"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.1"),
    ],
    targets: [
        .target(
            name: "PluginMemory",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitAgentTool",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
                .product(name: "ProviderStorage", package: "LumiProviders"),
                "ProviderToolManager",
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
            ],
            path: "Sources/PluginMemory",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PluginMemoryTests",
            dependencies: [
                "PluginMemory",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Tests/PluginMemoryTests"
        ),
    ]
)
