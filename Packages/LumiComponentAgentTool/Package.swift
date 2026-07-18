// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentAgentTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiComponentAgentTool", targets: ["LumiComponentAgentTool"])
    ],
    dependencies: [
        .package(path: "../LumiComponentMessage"),
    ],
    targets: [
        .target(
            name: "LumiComponentAgentTool",
            dependencies: [
                .product(name: "LumiComponentMessage", package: "LumiComponentMessage"),
            ],
            path: "Sources"
        ),
        .testTarget(name: "LumiComponentAgentToolTests", dependencies: ["LumiComponentAgentTool"])
    ]
)