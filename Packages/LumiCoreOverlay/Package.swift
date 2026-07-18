// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreOverlay",
    platforms: [.macOS(.v14)],
    products: [.library(name: "LumiCoreOverlay", targets: ["LumiCoreOverlay"])],
    dependencies: [],
    targets: [.target(name: "LumiCoreOverlay", path: "Sources")]
)