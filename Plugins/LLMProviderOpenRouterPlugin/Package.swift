// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderOpenRouterPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderOpenRouterPlugin",
            targets: ["LLMProviderOpenRouterPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LocalizationKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderOpenRouterPlugin",
            dependencies: [
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderOpenRouterPluginTests",
            dependencies: ["LLMProviderOpenRouterPlugin"],
            path: "Tests"
        )
    ]
)
