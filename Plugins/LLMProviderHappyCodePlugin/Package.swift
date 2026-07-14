// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderHappyCodePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderHappyCodePlugin",
            targets: ["LLMProviderHappyCodePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiLocalizationKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
    ],
    targets: [
        .target(
            name: "LLMProviderHappyCodePlugin",
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
            name: "LLMProviderHappyCodePluginTests",
            dependencies: ["LLMProviderHappyCodePlugin"],
            path: "Tests"
        )
    ]
)
