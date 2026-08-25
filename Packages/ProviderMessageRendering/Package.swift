// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderMessageRendering",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderMessageRendering", targets: ["ProviderMessageRendering"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
    ],
    targets: [
        .target(
            name: "ProviderMessageRendering",
            dependencies: [
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Sources/ProviderMessageRendering"
        ),
    ]
)
