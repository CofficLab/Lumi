// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPromptSuggestion",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderPromptSuggestion", targets: ["ProviderPromptSuggestion"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderPluginControl"),
        .package(path: "../ProviderPluginManaging"),
        .package(path: "../ProviderToast"),
        .package(path: "../ProviderWorkspace"),
    ],
    targets: [
        .target(name: "ProviderPromptSuggestion", dependencies: [
            .product(name: "KernelCore", package: "KernelCore"),
            .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
            .product(name: "ProviderPluginControl", package: "ProviderPluginControl"),
            .product(name: "ProviderPluginManaging", package: "ProviderPluginManaging"),
            .product(name: "ProviderToast", package: "ProviderToast"),
            .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
        ], path: "Sources/ProviderPromptSuggestion"),
        .testTarget(
            name: "ProviderPromptSuggestionTests",
            dependencies: ["ProviderPromptSuggestion"]
        ),
    ]
)
