// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentAvailableTools",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginAgentAvailableTools",
            targets: ["PluginAgentAvailableTools"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginAgentAvailableTools",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit",
            path: "Sources"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginAgentAvailableToolsTests",
            dependencies: ["PluginAgentAvailableTools"],
            path: "Tests"
        )
    ]
)
