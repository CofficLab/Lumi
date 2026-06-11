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
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
    ],
    targets: [
        .target(
            name: "LLMProviderXiaomiPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLLMProviderSupport", package: "LumiLLMProviderSupport"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderXiaomiPluginTests",
            dependencies: ["LLMProviderXiaomiPlugin"],
            path: "Tests"
        )
    ]
)
