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
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitHTMLPreview"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderToolManager"),
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
                "KitAgentTool",
                "KitHTMLPreview",
                "ProviderMessage",
                "ProviderMessageRendering",
                "ProviderToolManager",
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
                "KitAgentTool",
                "ProviderMessage",
                "ProviderMessageRendering",
                "ProviderToolManager",
            ],
            path: "Tests/PluginHTMLCanvasTests"
        ),
    ]
)
