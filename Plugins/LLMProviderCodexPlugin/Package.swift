// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderCodexPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderCodexPlugin",
            targets: ["LLMProviderCodexPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "LLMProviderCodexPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            exclude: [
                "CodexPlugin.swift",
                "CodexProvider.swift",
            ],
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderCodexPluginTests",
            dependencies: ["LLMProviderCodexPlugin"],
            path: "Tests"
        )
    ]
)
