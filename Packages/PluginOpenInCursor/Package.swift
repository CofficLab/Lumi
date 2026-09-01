// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInCursor",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginOpenInCursor", targets: ["PluginOpenInCursor"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog"),
        .package(path: "../OpenInKit"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginOpenInCursor",
            dependencies: [
                "KernelCore",
                "KitLocalization",
                "KitSuperLog",
                "OpenInKit",
                "ProviderDocsView",
                "ProviderProject",
                "ProviderToolManager",
            ],
            path: "Sources/PluginOpenInCursor",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
    ]
)
