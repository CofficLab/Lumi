// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderDeepSeekPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderDeepSeekPlugin",
            targets: ["LLMProviderDeepSeekPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/KeychainKit"),
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderDeepSeekPlugin",
            dependencies: [
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "KeychainKit", package: "KeychainKit"),
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderDeepSeekPluginTests",
            dependencies: ["LLMProviderDeepSeekPlugin"],
            path: "Tests"
        )
    ]
)
