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
    ],
    targets: [
        .target(
            name: "LumiComponentSubAgent",
            dependencies: [
                .product(name: "LumiComponentMessage", package: "LumiComponentMessage"),
                .product(name: "LumiComponentAgentTool", package: "LumiComponentAgentTool"),
            ],
            path: "Sources"
        ),
        .testTarget(name: "LumiComponentSubAgentTests", dependencies: ["LumiComponentSubAgent"])
    ]
)