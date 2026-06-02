// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "PluginAskUser",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginAskUser", targets: ["PluginAskUser"]),
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginAskUser",
            dependencies: [
                "AgentToolKit",
                "SuperLogKit",
                "LumiCoreKit",
                "LumiUI",
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "PluginAskUserTests",
            dependencies: ["PluginAskUser"],
            path: "Tests"
        ),
    ]
)
