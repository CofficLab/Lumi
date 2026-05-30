// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToolCallLoopDetection",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginToolCallLoopDetection",
            targets: ["PluginToolCallLoopDetection"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginToolCallLoopDetection",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginToolCallLoopDetection",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginToolCallLoopDetectionTests",
            dependencies: ["PluginToolCallLoopDetection"],
            path: "Tests/PluginToolCallLoopDetectionTests"
        )
    ]
)
