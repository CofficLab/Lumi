// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreGit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiCoreGit",
            targets: ["LumiCoreGit"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LumiCoreGit",
            path: "Sources"
        ),
    ]
)