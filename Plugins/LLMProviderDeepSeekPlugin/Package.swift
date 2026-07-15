// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderDeepSeekPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderDeepSeekPlugin",
            targets: ["LLMProviderDeepSeekPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiLocalizationKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
    ],
    targets: [
        .target(
            name: "LLMProviderDeepSeekPlugin",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "LumiLLMProviderSupport", package: "LumiLLMProviderSupport"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderDeepSeekPluginTests",
            dependencies: ["LLMProviderDeepSeekPlugin"],
            path: "Tests"
        )
    ]
)
