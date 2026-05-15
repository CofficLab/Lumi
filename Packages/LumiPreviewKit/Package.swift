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
            name: "LumiHotPreviewHostApp",
            targets: ["LumiHotPreviewHostApp"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LumiPreviewKit",
            path: "Sources/LumiPreviewKit"
        ),
        .executableTarget(
            name: "LumiHotPreviewHostApp",
            dependencies: ["LumiPreviewKit"],
            path: "Sources/LumiHotPreviewHostApp"
        ),
        .testTarget(
            name: "LumiPreviewKitTests",
            dependencies: ["LumiPreviewKit"],
            path: "Tests/LumiPreviewKitTests"
        )
    ]
)
