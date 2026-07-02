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
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
    ],
    targets: [
        .target(
            name: "LLMProviderMegaLLMPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLLMProviderSupport", package: "LumiLLMProviderSupport"),
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
