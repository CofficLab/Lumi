// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderSublyxPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderSublyxPlugin",
            targets: ["LLMProviderSublyxPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
    ],
    targets: [
        .target(
            name: "LLMProviderSublyxPlugin",
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
            name: "LLMProviderSublyxPluginTests",
            dependencies: ["LLMProviderSublyxPlugin"],
            path: "Tests"
        )
    ]
)
