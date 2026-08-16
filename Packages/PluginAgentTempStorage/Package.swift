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
        .package(path: "../AgentToolKit"),
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .testTarget(
            name: "PluginAgentTempStorageTests",
            dependencies: ["PluginAgentTempStorage", "AgentToolKit"]
        ),
        .target(
            name: "PluginAgentTempStorage",
            dependencies: [
                "AgentToolKit",
                "KernelCore",
                "LocalizationKit",
                "ProviderStorage",
                "ProviderToolManager",
                "SuperLogKit",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
    ]
)
