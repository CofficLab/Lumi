// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentGitHubTools",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginAgentGitHubTools",
            targets: ["PluginAgentGitHubTools"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/GitHubKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginAgentGitHubTools",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "GitHubKit", package: "GitHubKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginAgentGitHubTools",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginAgentGitHubToolsTests",
            dependencies: ["PluginAgentGitHubTools"],
            path: "Tests"
        )
    ]
)
