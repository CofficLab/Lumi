// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCodeReview",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginCodeReview",
            targets: ["PluginCodeReview"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../LLMKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginCodeReview",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginCodeReview"
        ),
        .testTarget(
            name: "PluginCodeReviewTests",
            dependencies: ["PluginCodeReview"],
            path: "Tests/PluginCodeReviewTests"
        )
    ]
)
