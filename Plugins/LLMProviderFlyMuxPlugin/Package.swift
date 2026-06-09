// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderFlyMuxPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderFlyMuxPlugin",
            targets: ["LLMProviderFlyMuxPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
    ],
    targets: [
        .target(
            name: "LLMProviderFlyMuxPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLLMProviderSupport", package: "LumiLLMProviderSupport"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LLMProviderFlyMuxPluginTests",
            dependencies: ["LLMProviderFlyMuxPlugin"],
            path: "Tests"
        )
    ]
)
