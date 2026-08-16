// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDocxRead",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginDocxRead", targets: ["PluginDocxRead"]),
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginDocxRead",
            dependencies: [
                "AgentToolKit",
                "KernelCore",
                "LocalizationKit",
                "ProviderToolManager",
                "SuperLogKit",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
    ]
)
