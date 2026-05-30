// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorPreview",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorPreview",
            targets: ["PluginEditorPreview"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/HTMLPreviewKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiPreviewKit"),
        .package(path: "../../Packages/MarkdownKit"),
        .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.0"),
        .package(path: "../../Packages/StringCatalogKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorPreview",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "HTMLPreviewKit", package: "HTMLPreviewKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiPreviewKit", package: "LumiPreviewKit"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
                .product(name: "MagicAlert", package: "MagicAlert"),
                .product(name: "StringCatalogKit", package: "StringCatalogKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginEditorPreview",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorPreviewTests",
            dependencies: ["PluginEditorPreview"],
            path: "Tests/PluginEditorPreviewTests"
        )
    ]
)
