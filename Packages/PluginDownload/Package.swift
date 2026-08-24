// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDownload",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginDownload",
            targets: ["DownloadPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../AgentToolKit"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../LocalizationKit"),        .package(path: "../DownloadKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "DownloadPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "DownloadKit", package: "DownloadKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
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
