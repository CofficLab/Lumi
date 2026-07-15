// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPreviewKit",
    defaultLocalization: "en",
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
    dependencies: [
        .package(path: "../SuperLogKit"),
        .package(path: "../LumiLocalizationKit"),
    ],
    targets: [
        .target(
            name: "LumiPreviewKit",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
            ],
            path: "Sources",
            exclude: ["LumiPreviewHostApp"],
            resources: [
                .process("../Resources")
            ]
        ),
        .executableTarget(
            name: "LumiPreviewHostApp",
            dependencies: ["LumiPreviewKit"],
            path: "Sources/LumiPreviewHostApp"
        ),
        .testTarget(
            name: "LumiPreviewKitTests",
            dependencies: ["LumiPreviewKit"],
            path: "Tests"
        )
    ]
)
