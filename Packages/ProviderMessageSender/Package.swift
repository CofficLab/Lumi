// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderMessageSender",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderMessageSender", targets: ["ProviderMessageSender"]),
    ],
    dependencies: [
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "ProviderMessageSender",
            dependencies: [
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources/ProviderMessageSender"
        ),
        .testTarget(
            name: "ProviderMessageSenderTests",
            dependencies: ["ProviderMessageSender"]
        )
    ]
)
