// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOcr",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginOcr", targets: ["PluginOcr"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0")
    ],
    targets: [
        .target(
            name: "PluginOcr",
            dependencies: [
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                "LumiUI",
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                "ProviderToolManager",
            ]
        ),
        .testTarget(
            name: "PluginOcrTests",
            dependencies: [
                "PluginOcr",
                "KitAgentTool",
            ]
        ),
    ]
)
