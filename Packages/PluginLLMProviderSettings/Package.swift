// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderSettings",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderSettings", targets: ["PluginLLMProviderSettings"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderSettings",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
            ],
            path: "Sources/PluginLLMProviderSettings"
        ),
        .testTarget(
            name: "PluginLLMProviderSettingsTests",
            dependencies: [
                "PluginLLMProviderSettings",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
            ],
            path: "Tests/PluginLLMProviderSettingsTests"
        ),
    ]
)
