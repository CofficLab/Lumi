// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderMessageSender",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "ProviderMessageSender", targets: ["ProviderMessageSender"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.24.0"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "ProviderMessageSender",
            dependencies: [
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/ProviderMessageSender"
        ),
        .testTarget(
            name: "ProviderMessageSenderTests",
            dependencies: ["ProviderMessageSender"]
        )
    ]
)
