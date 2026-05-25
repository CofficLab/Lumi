// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectOverview",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginProjectOverview",
            targets: ["PluginProjectOverview"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../SuperLogKit"),
        .package(path: "../ShellKit"),
    ],
    targets: [
        .target(
            name: "PluginProjectOverview",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "ShellKit", package: "ShellKit"),
            ],
            path: "Sources/PluginProjectOverview",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginProjectOverviewTests",
            dependencies: ["PluginProjectOverview"],
            path: "Tests/PluginProjectOverviewTests"
        )
    ]
)
