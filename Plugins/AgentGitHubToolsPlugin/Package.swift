// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentGitHubToolsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AgentGitHubToolsPlugin",
            targets: ["AgentGitHubToolsPlugin"]
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
            name: "AgentGitHubToolsPlugin",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "GitHubKit", package: "GitHubKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AgentGitHubToolsPluginTests",
            dependencies: ["AgentGitHubToolsPlugin"],
            path: "Tests"
        )
    ]
)
