// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInFinder",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginOpenInFinder", targets: ["PluginOpenInFinder"]),
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
            name: "PluginOpenInFinder",
            dependencies: [
                "KernelCore",
                "KitLocalization",
                "KitSuperLog",
                "OpenInKit",
                "ProviderDocsView",
                "ProviderProject",
                "ProviderToolManager",
            ],
            path: "Sources/PluginOpenInFinder",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
    ]
)
