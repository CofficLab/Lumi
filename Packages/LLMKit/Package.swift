// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "LLMKit",
            targets: ["LLMKit"]
        ),
    ],
    dependencies: [
        .package(name: "HttpKit", path: "../HttpKit"),
        .package(path: "../LocalizationKit"),
        .package(path: "../KeychainKit"),
        .package(path: "../KernelLumi"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LLMKit",
            dependencies: [
                "HttpKit",
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "KeychainKit", package: "KeychainKit"),
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/LLMKit",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LLMKitTests",
            dependencies: [
                "LLMKit",
                .product(name: "KeychainKit", package: "KeychainKit"),
            ],
            path: "Tests"
        ),
    ]
)
