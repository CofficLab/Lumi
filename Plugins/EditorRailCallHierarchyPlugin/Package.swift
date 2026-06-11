// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorRailCallHierarchyPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorRailCallHierarchyPlugin",
            targets: ["EditorRailCallHierarchyPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../EditorBottomCallHierarchyPlugin"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorRailCallHierarchyPlugin",
            dependencies: [
                .product(name: "EditorBottomCallHierarchyPlugin", package: "EditorBottomCallHierarchyPlugin"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorRailCallHierarchyPluginTests",
            dependencies: ["EditorRailCallHierarchyPlugin"],
            path: "Tests"
        )
    ]
)
