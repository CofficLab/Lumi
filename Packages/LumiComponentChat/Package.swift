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
        .package(path: "../LumiComponentPlugin"),
        .package(path: "../LumiComponentLayout"),
        .package(path: "../LumiComponentLLMProvider"),
        .package(path: "../LLMKit"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LumiComponentChat",
            dependencies: [
                .product(name: "LumiComponentMessage", package: "LumiComponentMessage"),
                .product(name: "LumiComponentAgentTool", package: "LumiComponentAgentTool"),
                .product(name: "LumiComponentPlugin", package: "LumiComponentPlugin"),
                .product(name: "LumiComponentLayout", package: "LumiComponentLayout"),
                .product(name: "LumiComponentLLMProvider", package: "LumiComponentLLMProvider"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
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