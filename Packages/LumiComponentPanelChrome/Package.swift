// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentPanelChrome",
    platforms: [.macOS(.v14)],
    products: [.library(name: "LumiComponentPanelChrome", targets: ["LumiComponentPanelChrome"])],
    dependencies: [],
    targets: [.target(name: "LumiComponentPanelChrome", path: "Sources")]
)