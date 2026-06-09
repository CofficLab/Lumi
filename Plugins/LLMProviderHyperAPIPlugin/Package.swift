// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderHyperAPIPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderHyperAPIPlugin",
            targets: ["LLMProviderHyperAPIPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
    ],
    targets: [
        .target(
            name: "LLMProviderHyperAPIPlugin",
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
            name: "LLMProviderHyperAPIPluginTests",
            dependencies: ["LLMProviderHyperAPIPlugin"],
            path: "Tests"
        )
    ]
)
