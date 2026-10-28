// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInRemote",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginOpenInRemote", targets: ["PluginOpenInRemote"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.12.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.11.1"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderGit"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginOpenInRemote",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                "KitAgentTool",
                "ProviderGit",
                "ProviderToolManager",
            ],
            path: "Sources/PluginOpenInRemote",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginOpenInRemoteTests",
            dependencies: [
                "PluginOpenInRemote",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                "KitAgentTool",
                "ProviderGit",
                "ProviderToolManager",
            ]
        ),
    ]
)
