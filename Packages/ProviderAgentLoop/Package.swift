// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderAgentLoop",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderAgentLoop", targets: ["ProviderAgentLoop"]),
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderLLMVendors"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderMessageStreaming"),
        .package(path: "../ProviderConversation"),
    ],
    targets: [
        .target(
            name: "ProviderAgentLoop",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderLLMVendors", package: "ProviderLLMVendors"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
            ],
            path: "Sources/ProviderAgentLoop"
        ),
        .testTarget(
            name: "ProviderAgentLoopTests",
            dependencies: ["ProviderAgentLoop"]
        )
    ]
)
