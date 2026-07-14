// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderFeifeimiaoPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderFeifeimiaoPlugin",
            targets: ["LLMProviderFeifeimiaoPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiLocalizationKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
    ],
    targets: [
        .target(
            name: "LLMProviderFeifeimiaoPlugin",
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
            name: "LLMProviderFeifeimiaoPluginTests",
            dependencies: ["LLMProviderFeifeimiaoPlugin"],
            path: "Tests"
        )
    ]
)
