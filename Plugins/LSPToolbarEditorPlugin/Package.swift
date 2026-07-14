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
        .package(path: "../../Packages/LumiLocalizationKit"),    ],
    targets: [
        .target(
            name: "LSPToolbarEditorPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LSPToolbarEditorPluginTests",
            dependencies: ["LSPToolbarEditorPlugin"],
            path: "Tests"
        )
    ]
)
