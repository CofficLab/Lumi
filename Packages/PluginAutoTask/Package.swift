// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAutoTask",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginAutoTask",
            targets: ["PluginAutoTask"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginAutoTask",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginAutoTask",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginAutoTaskTests",
            dependencies: ["PluginAutoTask"],
            path: "Tests/PluginAutoTaskTests"
        )
    ]
)
