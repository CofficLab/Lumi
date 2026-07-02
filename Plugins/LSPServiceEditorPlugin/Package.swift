// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LSPServiceEditorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LSPServiceEditorPlugin",
            targets: ["LSPServiceEditorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "LSPServiceEditorPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LSPServiceEditorPluginTests",
            dependencies: ["LSPServiceEditorPlugin"],
            path: "Tests"
        )
    ]
)
