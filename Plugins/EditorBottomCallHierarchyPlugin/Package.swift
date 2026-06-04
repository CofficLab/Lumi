// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorBottomCallHierarchyPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorBottomCallHierarchyPlugin",
            targets: ["EditorBottomCallHierarchyPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorBottomCallHierarchyPlugin",
            dependencies: [
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
            name: "EditorBottomCallHierarchyPluginTests",
            dependencies: ["EditorBottomCallHierarchyPlugin"],
            path: "Tests"
        )
    ]
)
