// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiComponentPlugin", targets: ["LumiComponentPlugin"])
    ],
    dependencies: [
        .package(path: "../LumiComponentMessage"),
        .package(path: "../LumiComponentAgentTool"),
        .package(path: "../LumiComponentLLMProvider"),
        .package(path: "../LumiComponentLayout"),
    ],
    targets: [
        .target(
            name: "LumiComponentPlugin",
            dependencies: [
                .product(name: "LumiComponentMessage", package: "LumiComponentMessage"),
                .product(name: "LumiComponentAgentTool", package: "LumiComponentAgentTool"),
                .product(name: "LumiComponentLLMProvider", package: "LumiComponentLLMProvider"),
                .product(name: "LumiComponentLayout", package: "LumiComponentLayout"),
            ],
            path: "Sources"
        ),
        .testTarget(name: "LumiComponentPluginTests", dependencies: ["LumiComponentPlugin"])
    ]
)