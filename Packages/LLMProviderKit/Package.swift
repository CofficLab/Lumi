// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "LLMProviderKit",
            targets: ["LLMProviderKit"]
        ),
    ],
    dependencies: [
        .package(path: "../HttpKit"),
        .package(path: "../LLMKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderKit",
            dependencies: [
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LLMKit", package: "LLMKit"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "LLMProviderKitTests",
            dependencies: ["LLMProviderKit"],
            path: "Tests"
        ),
    ]
)
