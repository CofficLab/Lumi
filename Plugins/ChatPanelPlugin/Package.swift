// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatPanelPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ChatPanelPlugin",
            targets: ["ChatPanelPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiChatKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ChatInputEditorKit")
    ],
    targets: [
        .target(
            name: "ChatPanelPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiChatKit", package: "LumiChatKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ChatInputEditorKit", package: "ChatInputEditorKit")
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ChatPanelPluginTests",
            dependencies: ["ChatPanelPlugin"],
            path: "Tests"
        )
    ]
)
