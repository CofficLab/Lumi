// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderXiaomiPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderXiaomiPlugin",
            targets: ["LLMProviderXiaomiPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/HttpKit"),
        .package(path: "../../Packages/LumiLocalizationKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "LLMProviderXiaomiPlugin",
            dependencies: [
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "LumiLLMProviderSupport", package: "LumiLLMProviderSupport"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderXiaomiPluginTests",
            dependencies: [
                "LLMProviderXiaomiPlugin",
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "LumiLLMProviderSupport", package: "LumiLLMProviderSupport"),
            ],
            path: "Tests"
        )
    ]
)
