// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentCoreToolsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AgentCoreToolsPlugin",
            targets: ["AgentCoreToolsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/WorkspaceFileKit"),
    ],
    targets: [
        .target(
            name: "AgentCoreToolsPlugin",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "WorkspaceFileKit", package: "WorkspaceFileKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AgentCoreToolsPluginTests",
            dependencies: ["AgentCoreToolsPlugin"],
            path: "Tests"
        )
    ]
)
