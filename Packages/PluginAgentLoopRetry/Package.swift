// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentLoopRetry",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginAgentLoopRetry", targets: ["PluginAgentLoopRetry"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderAgentLoop.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderLifecycleHooks.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessage.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginAgentLoopRetry",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderAgentLoop", package: "LumiProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderLifecycleHooks", package: "LumiProviderLifecycleHooks"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
            ],
            path: "Sources/PluginAgentLoopRetry",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginAgentLoopRetryTests",
            dependencies: [
                "PluginAgentLoopRetry",
                .product(name: "ProviderAgentLoop", package: "LumiProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderLifecycleHooks", package: "LumiProviderLifecycleHooks"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
            ],
            path: "Tests/PluginAgentLoopRetryTests"
        ),
    ]
)
