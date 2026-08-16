// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderConversationInput",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderConversationInput", targets: ["ProviderConversationInput"]),
    ],
    targets: [
        .target(name: "ProviderConversationInput", path: "Sources/ProviderConversationInput"),
    ]
)
