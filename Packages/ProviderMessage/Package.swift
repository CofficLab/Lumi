// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderMessage",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderMessage", targets: ["ProviderMessage"]),
    ],
    dependencies: [
        .package(path: "../ProviderConversation"),
    ],
    targets: [
        .target(
            name: "ProviderMessage",
            dependencies: [.product(name: "ProviderConversation", package: "ProviderConversation")],
            path: "Sources/ProviderMessage"
        ),
        .testTarget(
            name: "ProviderMessageTests",
            dependencies: ["ProviderMessage"]
        )
    ]
)
