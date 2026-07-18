// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderXybbzPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderXybbzPlugin",
            targets: ["LLMProviderXybbzPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LocalizationKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderXybbzPlugin",
            dependencies: [
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderXybbzPluginTests",
            dependencies: ["LLMProviderXybbzPlugin"],
            path: "Tests"
        )
    ]
)
