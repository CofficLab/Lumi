// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPromptSuggestion",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderPromptSuggestion", targets: ["ProviderPromptSuggestion"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderActivityBar"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.7"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
    ],
    targets: [
        .target(name: "ProviderPromptSuggestion", dependencies: [
            .product(name: "KernelCore", package: "LumiKernel"),
            .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
            .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
            .product(name: "ProviderPluginControl", package: "LumiProviders"),
            .product(name: "ProviderPluginManaging", package: "LumiProviders"),
            .product(name: "ProviderRailView", package: "LumiProviders"),
            .product(name: "ProviderSettingView", package: "LumiSettings"),
            .product(name: "ProviderToast", package: "LumiProviders"),
        ],
            path: ".",
            sources: ["Sources/ProviderPromptSuggestion"],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "ProviderPromptSuggestionTests",
            dependencies: [
                "ProviderPromptSuggestion",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
            ]
        ),
    ]
)
