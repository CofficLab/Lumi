// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPreviewKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiPreviewKit",
            targets: ["LumiPreviewKit"]
        ),
        .library(
            name: "LumiInlinePreviewKit",
            targets: ["LumiInlinePreviewKit"]
        ),
        .executable(
            name: "LumiHotPreviewHostApp",
            targets: ["LumiHotPreviewHostApp"]
        ),
        .executable(
            name: "LumiInlinePreviewHostApp",
            targets: ["LumiInlinePreviewHostApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/MagicKit", branch: "main")
    ],
    targets: [
        .target(
            name: "LumiPreviewKit",
            path: "Sources/LumiPreviewKit"
        ),
        .target(
            name: "LumiInlinePreviewKit",
            dependencies: [
                "LumiPreviewKit",
                .product(name: "MagicKit", package: "MagicKit")
            ],
            path: "Sources/LumiInlinePreviewKit"
        ),
        .executableTarget(
            name: "LumiHotPreviewHostApp",
            dependencies: ["LumiPreviewKit"],
            path: "Sources/LumiHotPreviewHostApp"
        ),
        .executableTarget(
            name: "LumiInlinePreviewHostApp",
            dependencies: ["LumiInlinePreviewKit"],
            path: "Sources/LumiInlinePreviewHostApp"
        ),
        .testTarget(
            name: "LumiPreviewKitTests",
            dependencies: ["LumiPreviewKit"],
            path: "Tests/LumiPreviewKitTests"
        ),
        .testTarget(
            name: "LumiInlinePreviewKitTests",
            dependencies: ["LumiInlinePreviewKit"],
            path: "Tests/LumiInlinePreviewKitTests"
        )
    ]
)
