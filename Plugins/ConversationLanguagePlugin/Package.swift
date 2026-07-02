// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationLanguagePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConversationLanguagePlugin",
            targets: ["ConversationLanguagePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiChatKit"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "ConversationLanguagePlugin",
            dependencies: [
                .product(name: "LumiChatKit", package: "LumiChatKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ConversationLanguagePluginTests",
            dependencies: ["ConversationLanguagePlugin"],
            path: "Tests"
        )
    ]
)
