// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationNew",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginConversationNew",
            targets: ["PluginConversationNew"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginConversationNew",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginConversationNew",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginConversationNewTests",
            dependencies: [
                "PluginConversationNew",
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Tests/PluginConversationNewTests"
        )
    ]
)
