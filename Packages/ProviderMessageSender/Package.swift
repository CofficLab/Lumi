// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderMessageSender",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "ProviderMessageSender", targets: ["ProviderMessageSender"]),
    ],
    dependencies: [
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../../Vendor/LumiLogging"),
    ],
    targets: [
        .target(
            name: "ProviderMessageSender",
            dependencies: [
                .product(name: "ProviderConversation", package: "ProviderConversation"),
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
