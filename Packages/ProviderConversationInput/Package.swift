// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderConversationInput",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderConversationInput", targets: ["ProviderConversationInput"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "ProviderConversationInput",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/ProviderConversationInput"),
        .testTarget(
            name: "ProviderConversationInputTests",
            dependencies: ["ProviderConversationInput"],
            path: "Tests/ProviderConversationInputTests"),
    ]
)
