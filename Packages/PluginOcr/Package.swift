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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
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
