// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiUI",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "LumiUI",
            targets: ["LumiUI"]
        )
    ],
    targets: [
        .target(
            name: "LumiUI",
            path: ".",
            exclude: ["Tests", "README.md", "README_zh.md", "LICENSE"],
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
