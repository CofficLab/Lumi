// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginChatPendingMessages",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginChatPendingMessages",
            targets: ["PluginChatPendingMessages"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginChatPendingMessages",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginChatPendingMessages"
        ),
        .testTarget(
            name: "PluginChatPendingMessagesTests",
            dependencies: ["PluginChatPendingMessages"],
            path: "Tests/PluginChatPendingMessagesTests"
        )
    ]
)
