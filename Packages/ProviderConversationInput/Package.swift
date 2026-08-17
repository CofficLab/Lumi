// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderConversationInput",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderConversationInput", targets: ["ProviderConversationInput"]),
    ],
    dependencies: [
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ProviderConversationInput",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/ProviderConversationInput"),
    ]
)
