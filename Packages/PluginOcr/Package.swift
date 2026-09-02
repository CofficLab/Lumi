// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOcr",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginOcr", targets: ["PluginOcr"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginOcr",
            dependencies: [
                "KitAgentTool",
                "KernelCore",
                "LumiUI",
                "ProviderDocsView",
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
