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
        .package(path: "../../Packages/LumiPreviewKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/MarkdownKit"),
        .package(path: "../../Packages/StringCatalogKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "EditorPreviewPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "HTMLPreviewKit", package: "HTMLPreviewKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiPreviewKit", package: "LumiPreviewKit"),
                .product(name: "LumiUI", package: "LumiUI"),
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
