// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorOverlayKit",
    defaultLocalization: "en",
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
        .package(path: "../MarkdownKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorOverlayKit",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorOverlayKitTests",
            dependencies: ["EditorOverlayKit"],
            path: "Tests"
        )
    ]
)
