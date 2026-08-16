// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPromptSuggestion",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderPromptSuggestion", targets: ["ProviderPromptSuggestion"]),
    ],
    targets: [
        .target(name: "ProviderPromptSuggestion", path: "Sources/ProviderPromptSuggestion"),
    ]
)
