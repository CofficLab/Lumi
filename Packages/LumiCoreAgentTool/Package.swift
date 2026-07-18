// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreAgentTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiCoreAgentTool", targets: ["LumiCoreAgentTool"])
    ],
    dependencies: [
        .package(path: "../LumiCoreMessage"),
    ],
    targets: [
        .target(
            name: "LumiCoreAgentTool",
            dependencies: [
                .product(name: "LumiCoreMessage", package: "LumiCoreMessage"),
            ],
            path: "Sources"
        ),
        .testTarget(name: "LumiCoreAgentToolTests", dependencies: ["LumiCoreAgentTool"])
    ]
)