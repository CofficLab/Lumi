// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderAgentTurn",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderAgentTurn", targets: ["ProviderAgentTurn"]),
    ],
    targets: [
        .target(name: "ProviderAgentTurn", path: "Sources/ProviderAgentTurn"),
    ]
)
