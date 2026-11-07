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
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../KitAgentTool"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../../Vendor/LumiSettings"),
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
