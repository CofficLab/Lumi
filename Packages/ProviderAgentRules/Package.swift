// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderAgentRules",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderAgentRules", targets: ["ProviderAgentRules"]),
    ],
    targets: [
        .target(
            name: "ProviderAgentRules",
            path: "Sources/ProviderAgentRules"
        ),
        .testTarget(
            name: "ProviderAgentRulesTests",
            dependencies: ["ProviderAgentRules"],
            path: "Tests/ProviderAgentRulesTests"
        ),
    ]
)
