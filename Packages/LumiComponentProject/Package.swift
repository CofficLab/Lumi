// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentProject",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiComponentProject",
            targets: ["LumiComponentProject"]
        ),
    ],
    dependencies: [
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LumiComponentProject",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "LumiComponentProjectTests",
            dependencies: ["LumiComponentProject"]
        ),
    ]
)