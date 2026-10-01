// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginWebSearch",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginWebSearch", targets: ["PluginWebSearch"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.4.0"),
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(path: "../ProviderToolManager"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginWebSearch",
            dependencies: [
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderNetwork", package: "LumiProviders"),
                "ProviderToolManager",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginWebSearchTests",
            dependencies: [
                "PluginWebSearch",
                "KitAgentTool",
            ]
        ),
    ]
)
