// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginBrowserAgent",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginBrowserAgent",
            targets: ["PluginBrowserAgent"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/ShellKit"),
    ],
    targets: [
        .target(
            name: "PluginBrowserAgent",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "ShellKit", package: "ShellKit"),
            ],
            path: "Sources/PluginBrowserAgent",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginBrowserAgentTests",
            dependencies: ["PluginBrowserAgent"],
            path: "Tests/PluginBrowserAgentTests"
        )
    ]
)
