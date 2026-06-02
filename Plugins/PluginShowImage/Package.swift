// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginShowImage",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginShowImage",
            targets: ["PluginShowImage"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginShowImage",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginShowImage",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginShowImageTests",
            dependencies: ["PluginShowImage"],
            path: "Tests"
        )
    ]
)
