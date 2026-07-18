// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentLayout",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiComponentLayout",
            targets: ["LumiComponentLayout"]
        ),
    ],
    dependencies: [
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LumiComponentLayout",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources"
        ),
    ]
)