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
    ],
    targets: [
        .target(
            name: "EditorBottomCallHierarchyPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
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
