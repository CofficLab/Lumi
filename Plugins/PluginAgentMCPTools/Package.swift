// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentMCPTools",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginAgentMCPTools",
            targets: ["PluginAgentMCPTools"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", .upToNextMajor(from: "0.10.2")),
        .package(path: "../../Packages/MCPKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginAgentMCPTools",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "MCPKit", package: "MCPKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginAgentMCPTools",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginAgentMCPToolsTests",
            dependencies: ["PluginAgentMCPTools"],
            path: "Tests/PluginAgentMCPToolsTests"
        )
    ]
)
