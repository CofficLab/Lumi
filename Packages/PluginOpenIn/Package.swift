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
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../KitAgentTool"),
        .package(path: "../OpenInKit"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToolManager"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.7")
    ],
    targets: [
        .target(
            name: "PluginOpenIn",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitAgentTool",
                "OpenInKit",
                "ProviderProject",
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                "ProviderToolManager",
            ],
            path: "Sources/PluginOpenIn"
        ),
        .testTarget(
            name: "PluginOpenInTests",
            dependencies: [
                "PluginOpenIn",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderProject", package: "ProviderProject"),
            ],
            path: "Tests/PluginOpenInTests"
        ),
    ]
)
