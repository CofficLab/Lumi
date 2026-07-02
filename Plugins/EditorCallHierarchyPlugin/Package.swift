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
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorCallHierarchyPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorCallHierarchyPluginTests",
            dependencies: ["EditorCallHierarchyPlugin"],
            path: "Tests"
        )
    ]
)
