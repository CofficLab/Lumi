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
        .executable(
            name: "LumiPreviewHostApp",
            targets: ["LumiPreviewHostApp"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LumiPreviewKit",
            path: "Sources/LumiPreviewKit"
        ),
        .executableTarget(
            name: "LumiPreviewHostApp",
            dependencies: ["LumiPreviewKit"],
            path: "Sources/LumiPreviewHostApp"
        ),
        .testTarget(
            name: "LumiPreviewKitTests",
            dependencies: ["LumiPreviewKit"],
            path: "Tests/LumiPreviewKitTests"
        )
    ]
)
