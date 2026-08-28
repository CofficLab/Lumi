// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInGitOK",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginOpenInGitOK", targets: ["PluginOpenInGitOK"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../OpenInKit"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginOpenInGitOK",
            dependencies: [
                "KernelCore",
                "KitSuperLog",
                "OpenInKit",
                "ProviderProject",
                "ProviderToolManager",
            ],
            path: "Sources/PluginOpenInGitOK"
        ),
    ]
)