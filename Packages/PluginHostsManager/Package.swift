// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginHostsManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginHostsManager", targets: ["PluginHostsManager"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginHostsManager",
            dependencies: [
                "KernelCore",
                "KitLocalization",
                "LumiUI",
                "ProviderActivityBar",
                "ProviderContentView",
                "ProviderDocsView",
                "KitSuperLog",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginHostsManagerTests",
            dependencies: [
                "PluginHostsManager",
            ]
        ),
    ]
)
