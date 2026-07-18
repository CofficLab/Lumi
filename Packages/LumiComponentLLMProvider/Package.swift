// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiComponentLLMProvider",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiComponentLLMProvider", targets: ["LumiComponentLLMProvider"])
    ],
    dependencies: [
        .package(path: "../LumiComponentMessage"),
        .package(path: "../LumiComponentAgentTool"),
        .package(path: "../SuperLogKit"),
        .package(path: "../LocalizationKit"),
    ],
    targets: [
        .target(
            name: "LumiComponentLLMProvider",
            dependencies: [
                .product(name: "LumiComponentMessage", package: "LumiComponentMessage"),
                .product(name: "LumiComponentAgentTool", package: "LumiComponentAgentTool"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources"
        ),
        .testTarget(name: "LumiComponentLLMProviderTests", dependencies: ["LumiComponentLLMProvider"])
    ]
)