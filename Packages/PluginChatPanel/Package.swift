// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginChatPanel",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginChatPanel",
            targets: ["PluginChatPanel"]
        )
    ],
    dependencies: [
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginChatPanel",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginChatPanel"
        ),
        .testTarget(
            name: "PluginChatPanelTests",
            dependencies: ["PluginChatPanel"],
            path: "Tests/PluginChatPanelTests"
        )
    ]
)
