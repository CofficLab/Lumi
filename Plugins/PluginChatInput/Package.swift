// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginChatInput",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginChatInput",
            targets: ["PluginChatInput"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/ChatInputEditorKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginChatInput",
            dependencies: [
                .product(name: "ChatInputEditorKit", package: "ChatInputEditorKit",
            path: "Sources"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginChatInputTests",
            dependencies: [
                "PluginChatInput",
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Tests"
        )
    ]
)
