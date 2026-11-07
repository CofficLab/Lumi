// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderSettings",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderSettings", targets: ["PluginLLMProviderSettings"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiSettings"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderSettings",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "KitLLM", package: "KitLLM"),
            ],
            path: "Sources/PluginLLMProviderSettings",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginLLMProviderSettingsTests",
            dependencies: [
                "PluginLLMProviderSettings",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "KitLLM", package: "KitLLM"),
            ],
            path: "Tests/PluginLLMProviderSettingsTests"
        ),
    ]
)
