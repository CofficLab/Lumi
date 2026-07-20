// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreLLMProvider",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiCoreLLMProvider", targets: ["LumiCoreLLMProvider"])
    ],
    dependencies: [
        .package(path: "../LumiCoreMessage"),
        .package(path: "../LumiCoreAgentTool"),
        .package(path: "../SuperLogKit"),
        .package(path: "../LocalizationKit"),
    ],
    targets: [
        .target(
            name: "LumiCoreLLMProvider",
            dependencies: [
                .product(name: "LumiCoreMessage", package: "LumiCoreMessage"),
                .product(name: "LumiCoreAgentTool", package: "LumiCoreAgentTool"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources"
        )
    ]
)