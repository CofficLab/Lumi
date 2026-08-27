// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderCodex",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLLMProviderCodex",
            targets: ["PluginLLMProviderCodex"]
        )
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLLM"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderCodex",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLocalization", package: "KitLocalization"),
            ],
            path: "Sources",
            exclude: [
                "CodexPlugin.swift",
                "CodexLumiProvider.swift",
                "Views",
            ],
            resources: [.process("../Resources")]
        ),
        .testTarget(
            name: "PluginLLMProviderCodexTests",
            dependencies: ["PluginLLMProviderCodex"],
            path: "Tests"
        )
    ]
)
