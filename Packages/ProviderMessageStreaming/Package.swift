// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderMessageStreaming",
    platforms: [.macOS(.v14), .iOS(.v17)],
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
    ]
)
