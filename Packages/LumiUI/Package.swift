// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiUI",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "LumiUI",
            targets: ["LumiUI"]
        )
    ],
    dependencies: [
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "LumiUI",
            dependencies: [
                .product(name: "KitLocalization", package: "KitLocalization"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LumiUITests",
            dependencies: ["LumiUI"],
            path: "Tests"
        )
    ]
)
