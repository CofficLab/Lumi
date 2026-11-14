// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageSender",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginMessageSender", targets: ["PluginMessageSender"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginMessageSender",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginMessageSender"
        ),
        .testTarget(
            name: "PluginMessageSenderTests",
            dependencies: [
                "PluginMessageSender",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Tests/PluginMessageSenderTests"
        ),
    ]
)
