// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInAntigravity",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginOpenInAntigravity", targets: ["PluginOpenInAntigravity"]),
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
            name: "PluginOpenInAntigravity",
            dependencies: [
                "KernelCore",
                "KitSuperLog",
                "OpenInKit",
                "ProviderProject",
                "ProviderToolManager",
            ],
            path: "Sources/PluginOpenInAntigravity"
        ),
    ]
)