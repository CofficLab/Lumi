// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiUI",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiUI",
            targets: ["LumiUI"]
        )
    ],
    dependencies: [
        .package(path: "../LumiLocalizationKit"),
    ],
    targets: [
        .target(
            name: "LumiUI",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
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
