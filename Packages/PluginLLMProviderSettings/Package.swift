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
        .package(path: "../LumiUI"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderLLMVendors"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderSettings",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderLLMVendors", package: "ProviderLLMVendors"),
            ],
            path: "Sources/PluginLLMProviderSettings"
        ),
        .testTarget(
            name: "PluginLLMProviderSettingsTests",
            dependencies: [
                "PluginLLMProviderSettings",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderLLMVendors", package: "ProviderLLMVendors"),
            ],
            path: "Tests/PluginLLMProviderSettingsTests"
        ),
    ]
)
