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
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderPluginControl"),
        .package(path: "../ProviderPluginManaging"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderToast"),
    ],
    targets: [
        .target(name: "ProviderPromptSuggestion", dependencies: [
            .product(name: "KernelCore", package: "KernelCore"),
            .product(name: "KitLocalization", package: "KitLocalization"),
            .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
            .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
            .product(name: "ProviderPluginControl", package: "ProviderPluginControl"),
            .product(name: "ProviderPluginManaging", package: "ProviderPluginManaging"),
            .product(name: "ProviderRailView", package: "ProviderRailView"),
            .product(name: "ProviderToast", package: "ProviderToast"),
        ],
            path: ".",
            sources: ["Sources/ProviderPromptSuggestion"],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "ProviderPromptSuggestionTests",
            dependencies: [
                "ProviderPromptSuggestion",
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
            ]
        ),
    ]
)
