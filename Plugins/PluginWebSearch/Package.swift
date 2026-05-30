// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginWebSearch",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginWebSearch",
            targets: ["PluginWebSearch"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginWebSearch",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginWebSearch",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginWebSearchTests",
            dependencies: ["PluginWebSearch"],
            path: "Tests/PluginWebSearchTests"
        )
    ]
)
