// swift-tools-version: 6.0
import PackageDescription

let targets = [
    "ProviderAgentTurn", "ProviderConversationInput", "ProviderMessageStreaming",
    "ProviderMessageRendering", "ProviderPromptSuggestion", "ProviderWorkspace",
    "ProviderOnboarding", "ProviderCommand", "ProviderIdleTime",
    "ProviderLegacyData", "ProviderPluginControl"
]

let package = Package(
    name: "ProviderRuntime",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: targets.map { .library(name: $0, targets: [$0]) },
    dependencies: [
        .package(path: "../ProviderMessage"),
    ],
    targets: targets.map { name in
        if name == "ProviderMessageStreaming" || name == "ProviderMessageRendering" {
            return .target(
                name: name,
                dependencies: [.product(name: "ProviderMessage", package: "ProviderMessage")],
                path: "Sources/\(name)"
            )
        }
        return .target(name: name, path: "Sources/\(name)")
    }
)
