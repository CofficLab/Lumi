// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDownload",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginDownload",
            targets: ["DownloadPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderToolManager"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),        .package(path: "../KitDownload"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "DownloadPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),                .product(name: "KitDownload", package: "KitDownload"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "DownloadPluginTests",
            dependencies: ["DownloadPlugin"]
        )
    ]
)
