// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentTurn",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiComponentTurn", targets: ["LumiComponentTurn"])
    ],
    dependencies: [
        .package(path: "../LumiComponentMessage"),
        .package(path: "../LumiComponentAgentTool"),
    ],
    targets: [
        .target(
            name: "LumiComponentTurn",
            dependencies: [
                .product(name: "LumiComponentMessage", package: "LumiComponentMessage"),
                .product(name: "LumiComponentAgentTool", package: "LumiComponentAgentTool"),
            ],
            path: "Sources"
        ),
        .testTarget(name: "LumiComponentTurnTests", dependencies: ["LumiComponentTurn"])
    ]
)