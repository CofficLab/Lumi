// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorCallHierarchyPlugin",
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
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorCallHierarchyPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiKernel", package: "LumiKernel"),
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
