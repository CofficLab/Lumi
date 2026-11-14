// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInRemote",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginOpenInRemote", targets: ["PluginOpenInRemote"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.1"),
        .package(path: "../ProviderGit"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
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
