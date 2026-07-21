// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationTitlePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConversationTitlePlugin",
            targets: ["ConversationTitlePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/LumiCoreChat"),
        .package(path: "../../Packages/LumiCoreMessage"),
        .package(path: "../../Packages/LumiCoreAgentTool"),
    ],
    targets: [
        .target(
            name: "ConversationTitlePlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LumiCoreChat", package: "LumiCoreChat"),
                .product(name: "LumiCoreMessage", package: "LumiCoreMessage"),
                .product(name: "LumiCoreAgentTool", package: "LumiCoreAgentTool"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ConversationTitlePluginTests",
            dependencies: [
                "ConversationTitlePlugin",
            ],
            path: "Tests"
        )
    ]
)
