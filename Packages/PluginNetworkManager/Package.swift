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
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.2"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitHttp"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitLLM"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderMenuBar"),
        .package(path: "../ProviderNetwork"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitShell"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginNetworkManager",
            dependencies: [
                "KitAgentTool",
                "KitHttp",
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitLLM",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
                "ProviderActivityBar",
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                "ProviderMenuBar",
                "ProviderNetwork",
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                "ProviderToolManager",
                "KitShell",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
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
