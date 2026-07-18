// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderKimiCodePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderKimiCodePlugin",
            targets: ["LLMProviderKimiCodePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LocalizationKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderKimiCodePlugin",
            dependencies: [
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderKimiCodePluginTests",
            dependencies: ["LLMProviderKimiCodePlugin"],
            path: "Tests"
        )
    ]
)