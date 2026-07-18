// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderOpenAIPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderOpenAIPlugin",
            targets: ["LLMProviderOpenAIPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/HttpKit"),
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/LumiLocalizationKit"),
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderOpenAIPlugin",
            dependencies: [
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderOpenAIPluginTests",
            dependencies: ["LLMProviderOpenAIPlugin"],
            path: "Tests"
        )
    ]
)
