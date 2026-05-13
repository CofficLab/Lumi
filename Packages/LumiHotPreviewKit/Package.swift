// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiHotPreviewKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiHotPreviewKit",
            targets: ["LumiHotPreviewKit"]
        ),
        .executable(
            name: "LumiHotPreviewHostApp",
            targets: ["LumiHotPreviewHostApp"]
        )
    ],
    dependencies: [
        .package(path: "../LumiPreviewKit")
    ],
    targets: [
        .target(
            name: "LumiHotPreviewKit",
            dependencies: [
                .product(name: "LumiPreviewKit", package: "LumiPreviewKit")
            ],
            path: "Sources/LumiHotPreviewKit"
        ),
        .executableTarget(
            name: "LumiHotPreviewHostApp",
            dependencies: [
                "LumiHotPreviewKit",
                .product(name: "LumiPreviewKit", package: "LumiPreviewKit")
            ],
            path: "Sources/LumiHotPreviewHostApp"
        ),
        .testTarget(
            name: "LumiHotPreviewKitTests",
            dependencies: ["LumiHotPreviewKit"],
            path: "Tests/LumiHotPreviewKitTests"
        )
    ]
)
