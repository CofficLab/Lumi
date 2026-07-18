// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentAgentTool",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiComponentAgentTool",
            targets: ["LumiComponentAgentTool"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LumiComponentAgentTool",
            path: "Sources"
        ),
    ]
)