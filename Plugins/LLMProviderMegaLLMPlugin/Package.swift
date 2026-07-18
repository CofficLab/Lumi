// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderMegaLLMPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderMegaLLMPlugin",
            targets: ["LLMProviderMegaLLMPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiLocalizationKit"),
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderMegaLLMPlugin",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderMegaLLMPluginTests",
            dependencies: ["LLMProviderMegaLLMPlugin"],
            path: "Tests"
        )
    ]
)
