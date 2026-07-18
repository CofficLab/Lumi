// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreMenuBar",
    platforms: [.macOS(.v14)],
    products: [.library(name: "LumiCoreMenuBar", targets: ["LumiCoreMenuBar"])],
    dependencies: [],
    targets: [.target(name: "LumiCoreMenuBar", path: "Sources")]
)