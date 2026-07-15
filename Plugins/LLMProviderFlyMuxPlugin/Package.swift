// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderFlyMuxPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderFlyMuxPlugin",
            targets: ["LLMProviderFlyMuxPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiLocalizationKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
    ],
    targets: [
        .target(
            name: "LLMProviderFlyMuxPlugin",
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
            name: "LLMProviderFlyMuxPluginTests",
            dependencies: ["LLMProviderFlyMuxPlugin"],
            path: "Tests"
        )
    ]
)
