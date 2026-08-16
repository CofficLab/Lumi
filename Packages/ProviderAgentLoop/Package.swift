// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderAgentLoop",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderAgentLoop", targets: ["ProviderAgentLoop"]),
    ],
    dependencies: [
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderLLM"),
    ],
    targets: [
        .target(
            name: "ProviderAgentLoop",
            dependencies: [
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderLLM", package: "ProviderLLM"),
            ],
            path: "Sources/ProviderAgentLoop"
        ),
        .testTarget(
            name: "ProviderAgentLoopTests",
            dependencies: ["ProviderAgentLoop"]
        )
    ]
)
