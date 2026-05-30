// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentCoreTools",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginAgentCoreTools",
            targets: ["PluginAgentCoreTools"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../ShellKit"),
        .package(path: "../SuperLogKit"),
        .package(path: "../WorkspaceFileKit"),
    ],
    targets: [
        .target(
            name: "PluginAgentCoreTools",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "WorkspaceFileKit", package: "WorkspaceFileKit"),
            ],
            path: "Sources/PluginAgentCoreTools",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginAgentCoreToolsTests",
            dependencies: ["PluginAgentCoreTools"],
            path: "Tests/PluginAgentCoreToolsTests"
        )
    ]
)
