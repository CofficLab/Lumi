// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCorePanelChrome",
    platforms: [.macOS(.v14)],
    products: [.library(name: "LumiCorePanelChrome", targets: ["LumiCorePanelChrome"])],
    dependencies: [],
    targets: [.target(name: "LumiCorePanelChrome", path: "Sources")]
)