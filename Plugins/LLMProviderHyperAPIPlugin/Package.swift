// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderHyperAPIPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderHyperAPIPlugin",
            targets: ["LLMProviderHyperAPIPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LocalizationKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderHyperAPIPlugin",
            dependencies: [
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderHyperAPIPluginTests",
            dependencies: ["LLMProviderHyperAPIPlugin"],
            path: "Tests"
        )
    ]
)
