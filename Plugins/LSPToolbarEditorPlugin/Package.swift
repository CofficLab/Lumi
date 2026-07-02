// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LSPToolbarEditorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LSPToolbarEditorPlugin",
            targets: ["LSPToolbarEditorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "LSPToolbarEditorPlugin",
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
            name: "LSPToolbarEditorPluginTests",
            dependencies: ["LSPToolbarEditorPlugin"],
            path: "Tests"
        )
    ]
)
