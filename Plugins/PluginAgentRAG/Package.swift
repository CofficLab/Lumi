// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentRAG",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginAgentRAG",
            targets: ["PluginAgentRAG"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/RAGKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginAgentRAG",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "RAGKit", package: "RAGKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginAgentRAG",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginAgentRAGTests",
            dependencies: ["PluginAgentRAG"],
            path: "Tests"
        )
    ]
)
