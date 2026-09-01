// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInVSCode",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginOpenInVSCode", targets: ["PluginOpenInVSCode"]),
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
            name: "PluginOpenInVSCode",
            dependencies: [
                "KernelCore",
                "KitLocalization",
                "KitSuperLog",
                "OpenInKit",
                "ProviderDocsView",
                "ProviderProject",
                "ProviderToolManager",
            ],
            path: "Sources/PluginOpenInVSCode",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
    ]
)
