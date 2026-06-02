// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "LLMProviderKit",
            targets: ["LLMProviderKit"]
        ),
    ],
    targets: [
        .target(
            name: "LLMProviderKit",
            path: "Sources"
        ),
        .testTarget(
            name: "LLMProviderKitTests",
            dependencies: ["LLMProviderKit"],
            path: "Tests"
        ),
    ]
)
