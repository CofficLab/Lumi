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
        .package(path: "../LumiCoreMessage"),
    ],
    targets: [
        .target(
            name: "LLMKit",
            dependencies: [
                "HttpKit",
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "KeychainKit", package: "KeychainKit"),
                .product(name: "LumiCoreMessage", package: "LumiCoreMessage"),
            ],
            path: "Sources/LLMKit",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LLMKitTests",
            dependencies: ["LLMKit"],
            path: "Tests"
        ),
    ]
)