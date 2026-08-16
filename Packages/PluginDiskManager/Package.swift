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
        .package(path: "../AgentToolKit"),
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginDiskManager",
            dependencies: [
                "AgentToolKit",
                "KernelCore",
                "LocalizationKit",
                "LumiUI",
                "ProviderActivityBar",
                "ProviderContentView",
                "ProviderDocsView",
                "ProviderRailView",
                "ProviderToolManager",
                "SuperLogKit",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginDiskManagerTests",
            dependencies: [
                "PluginDiskManager",
                "AgentToolKit",
                "KernelCore",
                "ProviderToolManager",
            ]
        ),
    ]
)
