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
        .package(path: "../../Packages/LumiLocalizationKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
    ],
    targets: [
        .target(
            name: "LLMProviderKimiCodePlugin",
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
            name: "LLMProviderKimiCodePluginTests",
            dependencies: ["LLMProviderKimiCodePlugin"],
            path: "Tests"
        )
    ]
)