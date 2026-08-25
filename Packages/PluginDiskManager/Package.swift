// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDiskManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginDiskManager", targets: ["PluginDiskManager"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginDiskManager",
            dependencies: [
                "KitAgentTool",
                "KernelCore",
                "KitLocalization",
                "LumiUI",
                "ProviderActivityBar",
                "ProviderContentView",
                "ProviderDocsView",
                "ProviderRailView",
                "ProviderToolManager",
                "KitSuperLog",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginDiskManagerTests",
            dependencies: [
                "PluginDiskManager",
                "KitAgentTool",
                "KernelCore",
                "ProviderToolManager",
            ]
        ),
    ]
)
