// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiInlinePreviewKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiInlinePreviewKit",
            targets: ["LumiInlinePreviewKit"]
        ),
        .executable(
            name: "LumiInlinePreviewHostApp",
            targets: ["LumiInlinePreviewHostApp"]
        )
    ],
    dependencies: [
        .package(path: "../LumiPreviewKit"),
        .package(url: "https://github.com/CofficLab/MagicKit", branch: "main")
    ],
    targets: [
        .target(
            name: "LumiInlinePreviewKit",
            dependencies: [
                .product(name: "LumiPreviewKit", package: "LumiPreviewKit"),
                .product(name: "MagicKit", package: "MagicKit")
            ],
            path: "Sources/LumiInlinePreviewKit"
        ),
        .executableTarget(
            name: "LumiInlinePreviewHostApp",
            dependencies: ["LumiInlinePreviewKit"],
            path: "Sources/LumiInlinePreviewHostApp"
        ),
        .testTarget(
            name: "LumiInlinePreviewKitTests",
            dependencies: ["LumiInlinePreviewKit"],
            path: "Tests/LumiInlinePreviewKitTests"
        )
    ]
)
