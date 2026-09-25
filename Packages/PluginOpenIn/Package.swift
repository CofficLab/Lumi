// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenIn",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginOpenIn", targets: ["PluginOpenIn"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitAgentTool"),
        .package(path: "../OpenInKit"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginOpenIn",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitAgentTool",
                "OpenInKit",
                "ProviderProject",
                "ProviderDocsView",
                "ProviderToolManager",
            ],
            path: "Sources/PluginOpenIn"
        ),
        .testTarget(
            name: "PluginOpenInTests",
            dependencies: [
                "PluginOpenIn",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderProject", package: "ProviderProject"),
            ],
            path: "Tests/PluginOpenInTests"
        ),
    ]
)
