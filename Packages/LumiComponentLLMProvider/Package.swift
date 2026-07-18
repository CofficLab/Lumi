// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentLLMProvider",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiComponentLLMProvider",
            targets: ["LumiComponentLLMProvider"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LumiComponentLLMProvider",
            path: "Sources"
        ),
    ]
)