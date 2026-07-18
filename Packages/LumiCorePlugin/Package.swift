// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCorePlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiCorePlugin", targets: ["LumiCorePlugin"])
    ],
    dependencies: [
        .package(path: "../LumiCoreMessage"),
        .package(path: "../LumiCoreAgentTool"),
        .package(path: "../LumiCoreLLMProvider"),
        .package(path: "../LumiCoreSubAgent"),
        .package(path: "../LumiCoreLayout"),
        .package(path: "../LumiCoreProject"),
        .package(path: "../LumiCoreMenuBar"),
        .package(path: "../LumiCoreOverlay"),
        .package(path: "../LumiCorePanelChrome"),
    ],
    targets: [
        .target(
            name: "LumiCorePlugin",
            dependencies: [
                .product(name: "LumiCoreMessage", package: "LumiCoreMessage"),
                .product(name: "LumiCoreAgentTool", package: "LumiCoreAgentTool"),
                .product(name: "LumiCoreLLMProvider", package: "LumiCoreLLMProvider"),
                .product(name: "LumiCoreSubAgent", package: "LumiCoreSubAgent"),
                .product(name: "LumiCoreLayout", package: "LumiCoreLayout"),
                .product(name: "LumiCoreProject", package: "LumiCoreProject"),
                .product(name: "LumiCoreMenuBar", package: "LumiCoreMenuBar"),
                .product(name: "LumiCoreOverlay", package: "LumiCoreOverlay"),
                .product(name: "LumiCorePanelChrome", package: "LumiCorePanelChrome"),
            ],
            path: "Sources"
        ),
        .testTarget(name: "LumiCorePluginTests", dependencies: ["LumiCorePlugin"])
    ]
)