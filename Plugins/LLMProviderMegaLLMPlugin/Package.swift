// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderMegaLLMPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderMegaLLMPlugin",
            targets: ["LLMProviderMegaLLMPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
    ],
    targets: [
        .target(
            name: "LLMProviderMegaLLMPlugin",
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
            name: "LLMProviderMegaLLMPluginTests",
            dependencies: ["LLMProviderMegaLLMPlugin"],
            path: "Tests"
        )
    ]
)
