// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginWebFetch",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginWebFetch", targets: ["PluginWebFetch"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(path: "../ProviderNetwork"),
        .package(path: "../ProviderToolManager"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginWebFetch",
            dependencies: [
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "ProviderNetwork",
                "ProviderToolManager",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginWebFetchTests",
            dependencies: [
                "PluginWebFetch",
                "KitAgentTool",
            ]
        ),
    ]
)
