// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorBottomCallHierarchy",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorBottomCallHierarchy",
            targets: ["PluginEditorBottomCallHierarchy"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorBottomCallHierarchy",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit",
            path: "Sources"),
                .product(name: "LumiUI", package: "LumiUI"),
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
            name: "PluginEditorBottomCallHierarchyTests",
            dependencies: ["PluginEditorBottomCallHierarchy"],
            path: "Tests"
        )
    ]
)
