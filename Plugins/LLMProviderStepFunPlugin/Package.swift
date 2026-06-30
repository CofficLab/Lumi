// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderStepFunPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderStepFunPlugin",
            targets: ["LLMProviderStepFunPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
    ],
    targets: [
        .target(
            name: "LLMProviderStepFunPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLLMProviderSupport", package: "LumiLLMProviderSupport"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderStepFunPluginTests",
            dependencies: ["LLMProviderStepFunPlugin"],
            path: "Tests"
        )
    ]
)
