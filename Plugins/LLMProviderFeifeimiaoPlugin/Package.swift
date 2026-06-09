// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderFeifeimiaoPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderFeifeimiaoPlugin",
            targets: ["LLMProviderFeifeimiaoPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
    ],
    targets: [
        .target(
            name: "LLMProviderFeifeimiaoPlugin",
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
            name: "LLMProviderFeifeimiaoPluginTests",
            dependencies: ["LLMProviderFeifeimiaoPlugin"],
            path: "Tests"
        )
    ]
)
