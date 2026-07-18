// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreSubAgent",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiCoreSubAgent", targets: ["LumiCoreSubAgent"])
    ],
    dependencies: [
        .package(path: "../LumiCoreMessage"),
        .package(path: "../LumiCoreAgentTool"),
        .package(path: "../LumiCoreLLMProvider"),
    ],
    targets: [
        .target(
            name: "LumiCoreSubAgent",
            dependencies: [
                .product(name: "LumiCoreMessage", package: "LumiCoreMessage"),
                .product(name: "LumiCoreAgentTool", package: "LumiCoreAgentTool"),
                .product(name: "LumiCoreLLMProvider", package: "LumiCoreLLMProvider"),
            ],
            path: "Sources"
        ),
        .testTarget(name: "LumiCoreSubAgentTests", dependencies: ["LumiCoreSubAgent"])
    ]
)