// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentDelayMessage",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginAgentDelayMessage",
            targets: ["PluginAgentDelayMessage"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginAgentDelayMessage",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginAgentDelayMessage",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginAgentDelayMessageTests",
            dependencies: ["PluginAgentDelayMessage"],
            path: "Tests/PluginAgentDelayMessageTests"
        )
    ]
)
