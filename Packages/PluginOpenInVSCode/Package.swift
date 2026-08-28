// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInVSCode",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginOpenInVSCode", targets: ["PluginOpenInVSCode"]),
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
            name: "PluginOpenInVSCode",
            dependencies: [
                "KernelCore",
                "KitSuperLog",
                "OpenInKit",
                "ProviderProject",
                "ProviderToolManager",
            ],
            path: "Sources/PluginOpenInVSCode"
        ),
    ]
)