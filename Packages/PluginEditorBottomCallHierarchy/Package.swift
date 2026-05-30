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
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorBottomCallHierarchy",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginEditorBottomCallHierarchy",
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
            path: "Tests/PluginEditorBottomCallHierarchyTests"
        )
    ]
)
