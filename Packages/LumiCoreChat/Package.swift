// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreChat",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiCoreChat", targets: ["LumiCoreChat"])
    ],
    dependencies: [
        .package(path: "../LumiCoreMessage"),
        .package(path: "../LumiCoreAgentTool"),
        .package(path: "../LumiKernel"),
        .package(path: "../LumiCoreLayout"),
        .package(path: "../LumiCoreLLMProvider"),
        .package(path: "../LLMKit"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LumiCoreChat",
            dependencies: [
                .product(name: "LumiCoreMessage", package: "LumiCoreMessage"),
                .product(name: "LumiCoreAgentTool", package: "LumiCoreAgentTool"),
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiCoreLayout", package: "LumiCoreLayout"),
                .product(name: "LumiCoreLLMProvider", package: "LumiCoreLLMProvider"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(name: "LumiCoreChatTests", dependencies: ["LumiCoreChat"])
    ]
)