// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderConversationState",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderConversationState", targets: ["ProviderConversationState"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ProviderConversationState",
            dependencies: [],
            path: "Sources/ProviderConversationState"
        ),
    ]
)
