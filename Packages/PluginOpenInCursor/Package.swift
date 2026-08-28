// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInCursor",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginOpenInCursor", targets: ["PluginOpenInCursor"]),
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
            name: "PluginOpenInCursor",
            dependencies: [
                "KernelCore",
                "KitSuperLog",
                "OpenInKit",
                "ProviderProject",
                "ProviderToolManager",
            ],
            path: "Sources/PluginOpenInCursor"
        ),
    ]
)