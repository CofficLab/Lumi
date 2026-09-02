// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCaffeinate",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginCaffeinate", targets: ["PluginCaffeinate"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderLogo"),
        .package(path: "../ProviderMenuBar"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginCaffeinate",
            dependencies: [
                "KitAgentTool",
                "KernelCore",
                "KitLocalization",
                "LumiUI",
                "ProviderDocsView",
                "ProviderLogo",
                "ProviderMenuBar",
                "ProviderStorage",
                "ProviderToolManager",
                "KitSuperLog",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginCaffeinateTests",
            dependencies: [
                "PluginCaffeinate",
                "KitAgentTool",
            ]
        ),
    ]
)
