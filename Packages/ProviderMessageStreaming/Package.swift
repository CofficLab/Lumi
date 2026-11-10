// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderMessageStreaming",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "ProviderMessageStreaming", targets: ["ProviderMessageStreaming"]),
    ],
    dependencies: [
        .package(path: "../ProviderMessage"),
    ],
    targets: [
        .target(
            name: "ProviderMessageStreaming",
            dependencies: [.product(name: "ProviderMessage", package: "ProviderMessage")],
            path: "Sources/ProviderMessageStreaming"
        ),
        .testTarget(
            name: "ProviderMessageStreamingTests",
            dependencies: [
                "ProviderMessageStreaming",
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ]
        ),
    ]
)
