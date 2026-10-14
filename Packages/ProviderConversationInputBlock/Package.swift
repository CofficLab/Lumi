// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderConversationInputBlock",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderConversationInputBlock",
            targets: ["ProviderConversationInputBlock"]
        ),
    ],
    targets: [
        .target(
            name: "ProviderConversationInputBlock",
            path: "Sources/ProviderConversationInputBlock"
        ),
        .testTarget(
            name: "ProviderConversationInputBlockTests",
            dependencies: ["ProviderConversationInputBlock"],
            path: "Tests/ProviderConversationInputBlockTests"
        )
    ]
)