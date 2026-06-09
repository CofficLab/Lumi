// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorPreviewPlugin",
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
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/HTMLPreviewKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LumiPreviewKit"),
        .package(path: "../../Packages/MarkdownKit"),
        .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.0"),
        .package(path: "../../Packages/StringCatalogKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorPreviewPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "HTMLPreviewKit", package: "HTMLPreviewKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiPreviewKit", package: "LumiPreviewKit"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
                .product(name: "MagicAlert", package: "MagicAlert"),
                .product(name: "StringCatalogKit", package: "StringCatalogKit"),
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
            name: "EditorPreviewPluginTests",
            dependencies: ["EditorPreviewPlugin"],
            path: "Tests"
        )
    ]
)
