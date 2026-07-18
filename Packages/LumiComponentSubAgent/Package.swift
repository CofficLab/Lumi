// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentSubAgent",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiComponentSubAgent", targets: ["LumiComponentSubAgent"])
    ],
    dependencies: [
        .package(path: "../LumiComponentMessage"),
        .package(path: "../LumiComponentAgentTool"),
        .package(path: "../LumiComponentLLMProvider"),
    ],
    targets: [
        .target(
            name: "LumiComponentSubAgent",
            dependencies: [
                .product(name: "LumiComponentMessage", package: "LumiComponentMessage"),
                .product(name: "LumiComponentAgentTool", package: "LumiComponentAgentTool"),
                .product(name: "LumiComponentLLMProvider", package: "LumiComponentLLMProvider"),
            ],
            path: "Sources"
        ),
        .testTarget(name: "LumiComponentSubAgentTests", dependencies: ["LumiComponentSubAgent"])
    ]
)