// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentTurn",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiComponentTurn",
            targets: ["LumiComponentTurn"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LumiComponentTurn",
            path: "Sources"
        ),
    ]
)