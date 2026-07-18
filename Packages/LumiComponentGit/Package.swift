// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentGit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiComponentGit",
            targets: ["LumiComponentGit"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LumiComponentGit",
            path: "Sources"
        ),
    ]
)