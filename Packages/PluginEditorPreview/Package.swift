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
            name: "EditorPreviewPlugin",
            targets: ["EditorPreviewPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../HTMLPreviewKit"),
        .package(path: "../KernelLumi"),
        .package(path: "../LumiPreviewKit"),
        .package(path: "../LumiUI"),
        .package(path: "../AgentToolKit"),
        .package(path: "../MarkdownKit"),
        .package(path: "../StringCatalogKit"),
        .package(path: "../SuperLogKit"),
        .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "EditorPreviewPlugin",
            dependencies: [
                .product(name: "HTMLPreviewKit", package: "HTMLPreviewKit"),
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiPreviewKit", package: "LumiPreviewKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "MagicAlert", package: "MagicAlert"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
                .product(name: "StringCatalogKit", package: "StringCatalogKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        )
    ]
)
