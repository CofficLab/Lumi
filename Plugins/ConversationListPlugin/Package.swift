// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationListPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConversationListPlugin",
            targets: ["ConversationListPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiChatKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ConversationListPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiChatKit", package: "LumiChatKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ConversationListPluginTests",
            dependencies: [
                "ConversationListPlugin",
                .product(name: "LumiChatKit", package: "LumiChatKit"),
            ],
            path: "Tests"
        )
    ]
)
