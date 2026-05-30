// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMultiAgent",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginMultiAgent",
            targets: ["PluginMultiAgent"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginMultiAgent",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginMultiAgent",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginMultiAgentTests",
            dependencies: ["PluginMultiAgent"],
            path: "Tests/PluginMultiAgentTests"
        )
    ]
)
