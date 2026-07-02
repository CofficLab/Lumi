// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderAnthropicPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderAnthropicPlugin",
            targets: ["LLMProviderAnthropicPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
    ],
    targets: [
        .target(
            name: "LLMProviderAnthropicPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLLMProviderSupport", package: "LumiLLMProviderSupport"),
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderAnthropicPluginTests",
            dependencies: ["LLMProviderAnthropicPlugin"],
            path: "Tests"
        )
    ]
)
