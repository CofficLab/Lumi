// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderCodex",
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
        .package(path: "../LLMKit"),
        .package(path: "../KernelLumi"),
        .package(path: "../AgentToolKit"),
        .package(path: "../HttpKit"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderCodexPlugin",
            dependencies: [
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
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