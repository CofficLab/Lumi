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
    ],
    targets: [
        .target(
            name: "LLMProviderCodexPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            exclude: [
                "CodexPlugin.swift",
                "CodexProvider.swift",
            ]
        ),
        .testTarget(
            name: "LLMProviderCodexPluginTests",
            dependencies: ["LLMProviderCodexPlugin"],
            path: "Tests"
        )
    ]
)
