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
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/EditorChatInputKit"),
        .package(path: "../../Packages/LumiCoreChat"),
        .package(path: "../../Packages/LumiCoreMessage"),
        .package(path: "../../Packages/LumiCoreAgentTool"),
        .package(path: "../../Packages/LumiCoreLayout"),
    ],
    targets: [
        .target(
            name: "ChatPanelPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "EditorChatInputKit", package: "EditorChatInputKit"),
                .product(name: "LumiCoreChat", package: "LumiCoreChat"),
                .product(name: "LumiCoreMessage", package: "LumiCoreMessage"),
                .product(name: "LumiCoreAgentTool", package: "LumiCoreAgentTool"),
                .product(name: "LumiCoreLayout", package: "LumiCoreLayout"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ChatPanelPluginTests",
            dependencies: ["ChatPanelPlugin"],
            path: "Tests"
        )
    ]
)
