// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageManager",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginMessageManager", targets: ["PluginMessageManager"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderAgentLoop"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginMessageManager",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderMessage",
                "ProviderConversation",
                .product(name: "ProviderStorage", package: "LumiProviders"),
                "ProviderAgentLoop",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ]
        ),
        .testTarget(
            name: "PluginMessageManagerTests",
            dependencies: [
                "PluginMessageManager",
                "ProviderMessage",
                "ProviderConversation",
            ],
            path: "Tests"
        ),
    ]
)
