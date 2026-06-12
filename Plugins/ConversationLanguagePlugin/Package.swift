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
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ConversationLanguagePlugin",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ConversationLanguagePluginTests",
            dependencies: ["ConversationLanguagePlugin"],
            path: "Tests"
        )
    ]
)
