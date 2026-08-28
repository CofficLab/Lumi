// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInFinder",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginOpenInFinder", targets: ["PluginOpenInFinder"]),
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
            name: "PluginOpenInFinder",
            dependencies: [
                "KernelCore",
                "KitSuperLog",
                "OpenInKit",
                "ProviderProject",
                "ProviderToolManager",
            ],
            path: "Sources/PluginOpenInFinder"
        ),
    ]
)