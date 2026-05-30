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
        .package(path: "../AgentToolKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../RAGKit"),
        .package(path: "../SuperLogKit"),
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
            path: "Tests/PluginAgentRAGTests"
        )
    ]
)
