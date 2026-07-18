// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreMessage",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiCoreMessage", targets: ["LumiCoreMessage"])
    ],
    dependencies: [],
    targets: [
        .target(name: "LumiCoreMessage", path: "Sources"),
        .testTarget(name: "LumiCoreMessageTests", dependencies: ["LumiCoreMessage"])
    ]
)
