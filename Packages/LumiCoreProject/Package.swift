// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreProject",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiCoreProject",
            targets: ["LumiCoreProject"]
        ),
    ],
    dependencies: [
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LumiCoreProject",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "LumiCoreProjectTests",
            dependencies: ["LumiCoreProject"]
        ),
    ]
)