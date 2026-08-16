// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderLLM",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderLLM", targets: ["ProviderLLM"]),
    ],
    dependencies: [
        .package(path: "../ProviderMessage"),
    ],
    targets: [
        .target(
            name: "ProviderLLM",
            dependencies: [.product(name: "ProviderMessage", package: "ProviderMessage")],
            path: "Sources/ProviderLLM"
        ),
        .testTarget(
            name: "ProviderLLMTests",
            dependencies: ["ProviderLLM"]
        ),
    ]
)
