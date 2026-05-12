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
        .package(path: "../EditorKernelCore"),
        .package(path: "../MarkdownKit"),
        .package(path: "../LumiUI"),
        .package(url: "https://github.com/CofficLab/MagicKit", from: "1.5.23"),
    ],
    targets: [
        .target(
            name: "EditorOverlayKit",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorKernelCore", package: "EditorKernelCore"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MagicKit", package: "MagicKit"),
            ],
            path: "Sources/EditorOverlayKit"
        )
    ]
)
