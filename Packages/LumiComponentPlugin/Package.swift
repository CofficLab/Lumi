// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentPlugin",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiComponentPlugin",
            targets: ["LumiComponentPlugin"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LumiComponentPlugin",
            path: "Sources"
        ),
    ]
)