// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentContextSync",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginAgentContextSync",
            targets: ["PluginAgentContextSync"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginAgentContextSync",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginAgentContextSync",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginAgentContextSyncTests",
            dependencies: ["PluginAgentContextSync"],
            path: "Tests/PluginAgentContextSyncTests"
        )
    ]
)
