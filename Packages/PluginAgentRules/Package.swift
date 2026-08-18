// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentRules",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginAgentRules", targets: ["PluginAgentRules"]),
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../KernelCore"),
        .package(path: "../SuperLogKit"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginAgentRules",
            dependencies: [
                "AgentToolKit",
                "KernelCore",
                "LocalizationKit",
                "LumiUI",
                "ProviderProject",
                "ProviderSettingView",
                "ProviderToolManager",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginAgentRulesTests",
            dependencies: [
                "PluginAgentRules",
                "AgentToolKit",
            ]
        ),
    ]
)
