// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGitHubInsight",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginGitHubInsight",
            targets: ["PluginGitHubInsight"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/GitHubKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ProjectProfileKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginGitHubInsight",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "GitHubKit", package: "GitHubKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProjectProfileKit", package: "ProjectProfileKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginGitHubInsight",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginGitHubInsightTests",
            dependencies: ["PluginGitHubInsight"],
            path: "Tests/PluginGitHubInsightTests"
        )
    ]
)
