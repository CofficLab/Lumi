// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentOverlay",
    platforms: [.macOS(.v14)],
    products: [.library(name: "LumiComponentOverlay", targets: ["LumiComponentOverlay"])],
    dependencies: [],
    targets: [.target(name: "LumiComponentOverlay", path: "Sources")]
)