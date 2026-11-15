// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentTempStorage",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginAgentTempStorage", targets: ["PluginAgentTempStorage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.24.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKitTestSupport.git", from: "1.0.0"),
    ],
    targets: [
        .testTarget(
            name: "PluginAgentTempStorageTests",
            dependencies: [
                "PluginAgentTempStorage",
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitTestSupport", package: "LumiKitTestSupport"),
                .product(name: "KitTestIsolation", package: "LumiKitTestSupport"),
            ]
        ),
        .target(
            name: "PluginAgentTempStorage",
            dependencies: [
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitTestIsolation", package: "LumiKitTestSupport"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
    ]
)
