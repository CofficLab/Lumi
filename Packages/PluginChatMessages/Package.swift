// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginChatMessages",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginChatMessages",
            targets: ["PluginChatMessages"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../MarkdownKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginChatMessages",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginChatMessages",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginChatMessagesTests",
            dependencies: ["PluginChatMessages"],
            path: "Tests/PluginChatMessagesTests"
        )
    ]
)
