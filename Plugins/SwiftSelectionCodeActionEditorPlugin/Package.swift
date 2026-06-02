// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftSelectionCodeActionEditorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftSelectionCodeActionEditorPlugin",
            targets: ["SwiftSelectionCodeActionEditorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "SwiftSelectionCodeActionEditorPlugin",
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
            name: "SwiftSelectionCodeActionEditorPluginTests",
            dependencies: ["SwiftSelectionCodeActionEditorPlugin"],
            path: "Tests"
        )
    ]
)
