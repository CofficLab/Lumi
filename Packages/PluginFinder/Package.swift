// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginFinder",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(
            name: "PluginFinder",
            targets: ["PluginFinder"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.1"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginFinder",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiUI", package: "LumiUI"),
                "KitAgentTool",
                "ProviderMessage",
                "ProviderMessageRendering",
                "ProviderToolManager",
            ],
            path: "Sources/PluginFinder",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginFinderTests",
            dependencies: [
                "PluginFinder",
                "KitAgentTool",
                "ProviderMessage",
                "ProviderMessageRendering",
            ],
            path: "Tests/PluginFinderTests"
        ),
    ]
)
