// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDiskSpeedTest",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "PluginDiskSpeedTest",
            targets: ["PluginDiskSpeedTest"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.18.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.11.1"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginDiskSpeedTest",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
                "KitAgentTool",
                "ProviderMessage",
                "ProviderMessageRendering",
                "ProviderToolManager",
            ],
            path: "Sources/PluginDiskSpeedTest",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginDiskSpeedTestTests",
            dependencies: [
                "PluginDiskSpeedTest",
                "KitAgentTool",
                "ProviderMessage",
                "ProviderMessageRendering",
            ],
            path: "Tests/PluginDiskSpeedTestTests"
        ),
    ]
)
