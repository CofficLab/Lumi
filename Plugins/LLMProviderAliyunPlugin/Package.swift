// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderAliyunPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderAliyunPlugin",
            targets: ["LLMProviderAliyunPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/HttpKit"),
        .package(path: "../../Packages/LumiLocalizationKit"),
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "LLMProviderAliyunPlugin",
            dependencies: [
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderAliyunPluginTests",
            dependencies: [
                "LLMProviderAliyunPlugin",
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Tests"
        )
    ]
)
