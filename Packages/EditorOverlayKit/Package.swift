// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorOverlayKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorOverlayKit",
            targets: ["EditorOverlayKit"]
        )
    ],
    dependencies: [
        .package(path: "../EditorService"),
        .package(path: "../EditorKernel"),
        .package(path: "../MarkdownKit"),
        .package(path: "../LumiUI"),
        .package(url: "https://github.com/CofficLab/MagicKit", from: "1.5.23"),
    ],
    targets: [
        .target(
            name: "EditorOverlayKit",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MagicKit", package: "MagicKit"),
            ],
            path: "Sources/EditorOverlayKit"
        )
    ]
)
