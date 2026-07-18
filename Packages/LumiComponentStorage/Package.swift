// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentStorage",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiComponentStorage",
            targets: ["LumiComponentStorage"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LumiComponentStorage",
            path: "Sources"
        ),
    ]
)