// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginQuickFileSearch",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginQuickFileSearch",
            targets: ["PluginQuickFileSearch"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../EditorService"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginQuickFileSearch",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginQuickFileSearch",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginQuickFileSearchTests",
            dependencies: ["PluginQuickFileSearch"],
            path: "Tests/PluginQuickFileSearchTests"
        )
    ]
)
