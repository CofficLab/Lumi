// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginChatAttachment",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginChatAttachment",
            targets: ["PluginChatAttachment"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginChatAttachment",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginChatAttachment"
        ),
        .testTarget(
            name: "PluginChatAttachmentTests",
            dependencies: ["PluginChatAttachment"],
            path: "Tests/PluginChatAttachmentTests"
        )
    ]
)
