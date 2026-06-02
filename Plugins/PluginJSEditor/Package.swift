// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginJSEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginJSEditor",
            targets: ["PluginJSEditor"]
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
            name: "PluginJSEditor",
            dependencies: [
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginJSEditorTests",
            dependencies: ["PluginJSEditor"],
            path: "Tests"
        )
    ]
)
