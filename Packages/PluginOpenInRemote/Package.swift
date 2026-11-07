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
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiUI"),
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
