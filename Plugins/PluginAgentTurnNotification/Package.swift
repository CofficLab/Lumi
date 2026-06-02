// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentTurnNotification",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginAgentTurnNotification",
            targets: ["PluginAgentTurnNotification"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginAgentTurnNotification",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit",
            path: "Sources"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginAgentTurnNotificationTests",
            dependencies: ["PluginAgentTurnNotification"],
            path: "Tests"
        )
    ]
)
