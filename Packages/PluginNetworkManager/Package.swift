// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginNetworkManager",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginNetworkManager", targets: ["PluginNetworkManager"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitHttp"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../KitLLM"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiSettings"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitShell"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../../Vendor/LumiLogging"),
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
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderMenuBar", package: "LumiProviders"),
                .product(name: "ProviderNetwork", package: "LumiProviders"),
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
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderMenuBar", package: "LumiProviders"),
                "ProviderToolManager",
            ]
        ),
    ]
)
