// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JSEditorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "JSEditorPlugin",
            targets: ["JSEditorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/CodeEditTextView"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "JSEditorPlugin",
            dependencies: [
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "ShellKit", package: "ShellKit"),
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
            name: "JSEditorPluginTests",
            dependencies: ["JSEditorPlugin"],
            path: "Tests"
        )
    ]
)
