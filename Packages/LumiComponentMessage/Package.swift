// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentMessage",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiComponentMessage", targets: ["LumiComponentMessage"])
    ],
    dependencies: [],
    targets: [
        .target(name: "LumiComponentMessage", path: "Sources"),
        .testTarget(name: "LumiComponentMessageTests", dependencies: ["LumiComponentMessage"])
    ]
)
