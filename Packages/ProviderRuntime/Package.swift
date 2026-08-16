// swift-tools-version: 6.0
import PackageDescription

let targets = [
    "ProviderAgentTurn", "ProviderConversationInput", "ProviderMessageStreaming",
    "ProviderMessageRendering", "ProviderPromptSuggestion", "ProviderWorkspace",
    "ProviderCommand", "ProviderIdleTime",
    "ProviderLegacyData", "ProviderPluginControl"
]

let package = Package(
    name: "ProviderRuntime",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: targets.map { .library(name: $0, targets: [$0]) },
    dependencies: [
        .package(path: "../ProviderMessage"),
        .package(path: "../KernelCore"),
    ],
    targets: targets.map { name in
        if name == "ProviderMessageStreaming" || name == "ProviderMessageRendering" {
            return .target(
                name: name,
                dependencies: [.product(name: "ProviderMessage", package: "ProviderMessage")],
                path: "Sources/\(name)"
            )
        }
        if name == "ProviderPluginControl" {
            return .target(
                name: name,
                dependencies: [.product(name: "KernelCore", package: "KernelCore")],
                path: "Sources/\(name)"
            )
        }
        return .target(name: name, path: "Sources/\(name)")
    } + [
        .testTarget(name: "ProviderWorkspaceTests", dependencies: ["ProviderWorkspace"]),
        .testTarget(
            name: "ProviderPluginControlTests",
            dependencies: [
                "ProviderPluginControl",
                .product(name: "KernelCore", package: "KernelCore"),
            ]
        )
    ]
)
