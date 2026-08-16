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
        .package(path: "../AgentToolKit"),
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderLogo"),
        .package(path: "../ProviderMenuBar"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginCaffeinate",
            dependencies: [
                "AgentToolKit",
                "KernelCore",
                "LocalizationKit",
                "LumiUI",
                "ProviderDocsView",
                "ProviderLogo",
                "ProviderMenuBar",
                "ProviderStorage",
                "ProviderToolManager",
                "SuperLogKit",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginCaffeinateTests",
            dependencies: [
                "PluginCaffeinate",
                "AgentToolKit",
            ]
        ),
    ]
)
