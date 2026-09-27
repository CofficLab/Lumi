// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderCodex",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginLLMProviderCodex",
            targets: ["PluginLLMProviderCodex"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitLLM"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderLLMManager"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderCodex",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
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
