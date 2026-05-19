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
        ),
        .executable(
            name: "LumiPreviewHostApp",
            targets: ["LumiPreviewHostApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/MagicKit", branch: "main")
    ],
    targets: [
        .target(
            name: "LumiPreviewKit",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit")
            ],
            path: "Sources/LumiPreviewKit"
        ),
        .executableTarget(
            name: "LumiHotPreviewHostApp",
            dependencies: ["LumiPreviewKit"],
            path: "Sources/LumiHotPreviewHostApp"
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
