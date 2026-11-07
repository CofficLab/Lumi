// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPromptSuggestionExecutor",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "ProviderPromptSuggestionExecutor", targets: ["ProviderPromptSuggestionExecutor"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiSettings"),
    ],
    targets: [
        .target(name: "ProviderPromptSuggestionExecutor", dependencies: [
            .product(name: "KernelCore", package: "LumiKernel"),
            .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
            .product(name: "ProviderActivityBar", package: "LumiProviders"),
            .product(name: "ProviderPluginControl", package: "LumiProviders"),
            .product(name: "ProviderPluginManaging", package: "LumiProviders"),
            .product(name: "ProviderPromptSuggestion", package: "LumiProviders"),
            .product(name: "ProviderRailView", package: "LumiProviders"),
            .product(name: "ProviderSettingView", package: "LumiSettings"),
            .product(name: "ProviderToast", package: "LumiProviders"),
        ],
            path: ".",
            sources: ["Sources/ProviderPromptSuggestionExecutor"],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "ProviderPromptSuggestionExecutorTests",
            dependencies: [
                "ProviderPromptSuggestionExecutor",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderPromptSuggestion", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
            ]
        ),
    ]
)
