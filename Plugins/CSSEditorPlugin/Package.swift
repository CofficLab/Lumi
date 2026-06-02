// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CSSEditorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CSSEditorPlugin",
            targets: ["CSSEditorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "CSSEditorPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CSSEditorPluginTests",
            dependencies: ["CSSEditorPlugin"],
            path: "Tests"
        )
    ]
)
