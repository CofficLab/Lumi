// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreLayout",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiCoreLayout",
            targets: ["LumiCoreLayout"]
        ),
    ],
    dependencies: [
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LumiCoreLayout",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources"
        ),
    ]
)