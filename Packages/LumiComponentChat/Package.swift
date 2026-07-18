// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentChat",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiComponentChat", targets: ["LumiComponentChat"])
    ],
    dependencies: [
        .package(path: "../LumiComponentMessage"),
        .package(path: "../LumiComponentAgentTool"),
    ],
    targets: [
        .target(
            name: "LumiComponentChat",
            dependencies: [
                .product(name: "LumiComponentMessage", package: "LumiComponentMessage"),
                .product(name: "LumiComponentAgentTool", package: "LumiComponentAgentTool"),
            ],
            path: "Sources"
        ),
        .testTarget(name: "LumiComponentChatTests", dependencies: ["LumiComponentChat"])
    ]
)