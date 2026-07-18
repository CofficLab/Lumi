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
        .package(path: "../LumiComponentSubAgent"),
        .package(path: "../LumiComponentLayout"),
        .package(path: "../LumiComponentProject"),
        .package(path: "../LumiComponentTurn"),
        .package(path: "../LumiComponentMenuBar"),
        .package(path: "../LumiComponentOverlay"),
        .package(path: "../LumiComponentPanelChrome"),
    ],
    targets: [
        .target(
            name: "LumiComponentPlugin",
            dependencies: [
                .product(name: "LumiComponentMessage", package: "LumiComponentMessage"),
                .product(name: "LumiComponentAgentTool", package: "LumiComponentAgentTool"),
                .product(name: "LumiComponentLLMProvider", package: "LumiComponentLLMProvider"),
                .product(name: "LumiComponentSubAgent", package: "LumiComponentSubAgent"),
                .product(name: "LumiComponentLayout", package: "LumiComponentLayout"),
                .product(name: "LumiComponentProject", package: "LumiComponentProject"),
                .product(name: "LumiComponentTurn", package: "LumiComponentTurn"),
                .product(name: "LumiComponentMenuBar", package: "LumiComponentMenuBar"),
                .product(name: "LumiComponentOverlay", package: "LumiComponentOverlay"),
                .product(name: "LumiComponentPanelChrome", package: "LumiComponentPanelChrome"),
            ],
            path: "Sources"
        ),
        .testTarget(name: "LumiComponentPluginTests", dependencies: ["LumiComponentPlugin"])
    ]
)