// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "PluginAskUser",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginAskUser", targets: ["PluginAskUser"]),
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../SuperLogKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
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
            resources: [.process("Resources")],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
    ]
)