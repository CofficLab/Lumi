// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorRailWorkspaceSearchPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorRailWorkspaceSearchPlugin",
            targets: ["EditorRailWorkspaceSearchPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorRailWorkspaceSearchPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            exclude: [
                "Views",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorRailWorkspaceSearchPluginTests",
            dependencies: ["EditorRailWorkspaceSearchPlugin"],
            path: "Tests"
        )
    ]
)
