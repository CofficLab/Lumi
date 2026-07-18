// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentChat",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiComponentChat", targets: ["LumiComponentChat"])
    ],
    dependencies: [
        .package(path: "../LumiComponentMessage"),
        .package(path: "../LumiComponentAgentTool"),
        .package(path: "../LumiComponentTurn"),
        .package(path: "../LumiComponentPlugin"),
        .package(path: "../LumiComponentLayout"),
        .package(path: "../LLMKit"),
        .package(path: "../LumiLocalizationKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LumiComponentChat",
            dependencies: [
                .product(name: "LumiComponentMessage", package: "LumiComponentMessage"),
                .product(name: "LumiComponentAgentTool", package: "LumiComponentAgentTool"),
                .product(name: "LumiComponentTurn", package: "LumiComponentTurn"),
                .product(name: "LumiComponentPlugin", package: "LumiComponentPlugin"),
                .product(name: "LumiComponentLayout", package: "LumiComponentLayout"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(name: "LumiComponentChatTests", dependencies: ["LumiComponentChat"])
    ]
)