// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorCallHierarchy",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorCallHierarchyPlugin",
            targets: ["EditorCallHierarchyPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorCallHierarchyPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorCallHierarchyPluginTests",
            dependencies: ["EditorCallHierarchyPlugin"],
            path: "Tests"
        )
    ]
)
