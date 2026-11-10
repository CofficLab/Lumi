// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderConversationState",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "ProviderConversationState", targets: ["ProviderConversationState"]),
    ],
    dependencies: [
        .package(path: "../ProviderAgentLoop"),
    ],
    targets: [
        .target(
            name: "ProviderConversationState",
            dependencies: [
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
            ],
            path: "Sources/ProviderConversationState"
        ),
        .testTarget(
            name: "ProviderConversationStateTests",
            dependencies: ["ProviderConversationState"]
        ),
    ]
)
