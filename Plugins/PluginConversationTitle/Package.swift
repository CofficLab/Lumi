// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationTitle",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginConversationTitle",
            targets: ["PluginConversationTitle"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginConversationTitle",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginConversationTitle",
            exclude: [
                "Middleware",
                "Tools",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginConversationTitleTests",
            dependencies: ["PluginConversationTitle"],
            path: "Tests/PluginConversationTitleTests"
        )
    ]
)
