// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginWebFetch",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginWebFetch", targets: ["PluginWebFetch"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderNetwork"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginWebFetch",
            dependencies: [
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitLocalization",
                "ProviderNetwork",
                "ProviderToolManager",
                "KitSuperLog",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginWebFetchTests",
            dependencies: [
                "PluginWebFetch",
                "KitAgentTool",
            ]
        ),
    ]
)
