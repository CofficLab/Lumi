// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MessageListPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MessageListPlugin",
            targets: ["MessageListPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiChatKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/MarkdownKit")
    ],
    targets: [
        .target(
            name: "MessageListPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiChatKit", package: "LumiChatKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MarkdownKit", package: "MarkdownKit")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "MessageListPluginTests",
            dependencies: [
                "MessageListPlugin",
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiChatKit", package: "LumiChatKit"),
                .product(name: "MarkdownKitTesting", package: "MarkdownKit")
            ],
            path: "Tests"
        )
    ]
)
