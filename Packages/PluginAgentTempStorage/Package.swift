// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentTempStorage",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginAgentTempStorage", targets: ["PluginAgentTempStorage"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .testTarget(
            name: "PluginAgentTempStorageTests",
            dependencies: ["PluginAgentTempStorage", "KitAgentTool"]
        ),
        .target(
            name: "PluginAgentTempStorage",
            dependencies: [
                "KitAgentTool",
                "KernelCore",
                "KitLocalization",
                "ProviderStorage",
                "ProviderToolManager",
                "KitSuperLog",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
    ]
)
