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
        .package(path: "../../Packages/LLMProviderKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport")
    ],
    targets: [
        .target(
            name: "LLMProviderOpenAIPlugin",
            dependencies: [
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LLMProviderKit", package: "LLMProviderKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLLMProviderSupport", package: "LumiLLMProviderSupport")
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
