// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginNetworkManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginNetworkManager", targets: ["PluginNetworkManager"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(path: "../KitHttp"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitLLM"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderMenuBar"),
        .package(path: "../ProviderNetwork"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitShell"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginNetworkManager",
            dependencies: [
                "KitAgentTool",
                "KitHttp",
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitLLM",
                "KitLocalization",
                "LumiUI",
                "ProviderActivityBar",
                "ProviderContentView",
                "ProviderDocsView",
                "ProviderMenuBar",
                "ProviderNetwork",
                "ProviderSettingView",
                "ProviderStorage",
                "ProviderToolManager",
                "KitShell",
                "KitSuperLog",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginNetworkManagerTests",
            dependencies: [
                "PluginNetworkManager",
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderToolManager",
            ]
        ),
    ]
)
