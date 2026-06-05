// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToolCallLoopDetectionPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ToolCallLoopDetectionPlugin",
            targets: ["ToolCallLoopDetectionPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ToolCallLoopDetectionPlugin",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ToolCallLoopDetectionPluginTests",
            dependencies: ["ToolCallLoopDetectionPlugin"],
            path: "Tests"
        )
    ]
)
