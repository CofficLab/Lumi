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
        .package(path: "../EditorService"),
        .package(path: "../HTMLPreviewKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiPreviewKit"),
        .package(path: "../MarkdownKit"),
        .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.0"),
        .package(path: "../StringCatalogKit"),
        .package(path: "../SuperLogKit"),
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
            exclude: [
                "Services",
                "ViewModels",
                "Views",
            ],
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
