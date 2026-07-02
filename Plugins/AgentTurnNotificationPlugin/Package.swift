// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentTurnNotificationPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AgentTurnNotificationPlugin",
            targets: ["AgentTurnNotificationPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "AgentTurnNotificationPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AgentTurnNotificationPluginTests",
            dependencies: ["AgentTurnNotificationPlugin"],
            path: "Tests"
        )
    ]
)
