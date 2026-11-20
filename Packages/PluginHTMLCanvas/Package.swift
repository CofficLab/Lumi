// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginHTMLCanvas",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(
            name: "PluginHTMLCanvas",
            targets: ["PluginHTMLCanvas"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.18.1"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.4"),
        .package(path: "../KitHTMLPreview"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessage.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessageRendering.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginHTMLCanvas",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                "KitHTMLPreview",
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
                .product(name: "ProviderMessageRendering", package: "LumiProviderMessageRendering"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
            ],
            path: "Sources/PluginHTMLCanvas",
            resources: [
                .process("../../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "PluginHTMLCanvasTests",
            dependencies: [
                "PluginHTMLCanvas",
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
                .product(name: "ProviderMessageRendering", package: "LumiProviderMessageRendering"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
            ],
            path: "Tests/PluginHTMLCanvasTests"
        ),
    ]
)
