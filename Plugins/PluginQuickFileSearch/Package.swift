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
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginQuickFileSearch",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit",
            path: "Sources"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginQuickFileSearchTests",
            dependencies: ["PluginQuickFileSearch"],
            path: "Tests"
        )
    ]
)
