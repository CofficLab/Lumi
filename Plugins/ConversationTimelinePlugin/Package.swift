// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationTimelinePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConversationTimelinePlugin",
            targets: ["ConversationTimelinePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiChatKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLocalizationKit"),        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ConversationTimelinePlugin",
            dependencies: [
                .product(name: "LumiChatKit", package: "LumiChatKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ConversationTimelinePluginTests",
            dependencies: ["ConversationTimelinePlugin"],
            path: "Tests"
        )
    ]
)
