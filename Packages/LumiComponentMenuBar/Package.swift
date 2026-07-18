// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentMenuBar",
    platforms: [.macOS(.v14)],
    products: [.library(name: "LumiComponentMenuBar", targets: ["LumiComponentMenuBar"])],
    dependencies: [],
    targets: [.target(name: "LumiComponentMenuBar", path: "Sources")]
)