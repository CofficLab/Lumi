// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationMessageCount",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "ConversationMessageCountPlugin",
            targets: ["ConversationMessageCountPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "ConversationMessageCountPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                        .product(name: "LocalizationKit", package: "LocalizationKit"),
],
            path: "Sources/ConversationMessageCountPlugin"
        ,
            resources: [.process("../../Resources/Localizable.xcstrings")])
    ]
)