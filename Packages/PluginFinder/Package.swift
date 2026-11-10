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
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderToolManager"),
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
