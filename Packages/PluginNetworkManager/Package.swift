// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginNetworkManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginNetworkManager", targets: ["PluginNetworkManager"]),
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../HttpKit"),
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderMenuBar"),
        .package(path: "../ProviderNetwork"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ShellKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginNetworkManager",
            dependencies: [
                "AgentToolKit",
                "HttpKit",
                "KernelCore",
                "LocalizationKit",
                "LumiUI",
                "ProviderActivityBar",
                "ProviderContentView",
                "ProviderDocsView",
                "ProviderMenuBar",
                "ProviderNetwork",
                "ProviderSettingView",
                "ProviderStorage",
                "ProviderToolManager",
                "ShellKit",
                "SuperLogKit",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginNetworkManagerTests",
            dependencies: [
                "PluginNetworkManager",
                "AgentToolKit",
                "KernelCore",
                "ProviderToolManager",
            ]
        ),
    ]
)
