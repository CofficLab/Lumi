// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorGoPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorGoPlugin",
            targets: ["EditorGoPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/CodeEditTextView"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/GoEditorCore"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorGoPlugin",
            dependencies: [
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "GoEditorCore", package: "GoEditorCore"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorGoPluginTests",
            dependencies: ["EditorGoPlugin"],
            path: "Tests"
        )
    ]
)
