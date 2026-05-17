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
        // Read-only 消费：仅复用 PreviewScanner + PreviewDiscovery，
        // 不修改 LumiPreviewKit，符合"不动老代码"边界。
        .package(path: "../LumiPreviewKit")
    ],
    targets: [
        .target(
            name: "LumiInlinePreviewKit",
            dependencies: [
                .product(name: "LumiPreviewKit", package: "LumiPreviewKit")
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
