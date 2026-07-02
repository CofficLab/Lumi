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
        .package(path: "../../Packages/LumiChatKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ConversationTitlePlugin",
            dependencies: [
                .product(name: "LumiChatKit", package: "LumiChatKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings")
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
