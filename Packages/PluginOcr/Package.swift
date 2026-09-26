// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOcr",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginOcr", targets: ["PluginOcr"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginOcr",
            dependencies: [
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
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
