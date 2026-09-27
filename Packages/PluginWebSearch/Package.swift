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
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(path: "../ProviderNetwork"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginWebSearch",
            dependencies: [
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "ProviderNetwork",
                "ProviderToolManager",
                "KitSuperLog",
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
