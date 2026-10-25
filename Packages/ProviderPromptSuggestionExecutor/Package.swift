// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPromptSuggestionExecutor",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderPromptSuggestionExecutor", targets: ["ProviderPromptSuggestionExecutor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(path: "../ProviderMessageSender"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.13.0"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.1.0"),
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
