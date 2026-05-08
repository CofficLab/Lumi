// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiUI",
    platforms: [
        .macOS(.v14)
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
            path: "Sources/LumiUI"
        ),
        .testTarget(
            name: "LumiUITests",
            dependencies: ["LumiUI"],
            path: "Tests/LumiUITests"
        )
    ]
)
