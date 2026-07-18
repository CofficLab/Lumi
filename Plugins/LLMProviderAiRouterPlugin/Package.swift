// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderAiRouterPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderAiRouterPlugin",
            targets: ["LLMProviderAiRouterPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LocalizationKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderAiRouterPlugin",
            dependencies: [
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderAiRouterPluginTests",
            dependencies: ["LLMProviderAiRouterPlugin"],
            path: "Tests"
        )
    ]
)
