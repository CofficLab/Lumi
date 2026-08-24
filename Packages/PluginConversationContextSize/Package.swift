// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationContextSize",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "ConversationContextSizePlugin",
            targets: ["ConversationContextSizePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "ConversationContextSizePlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                        .product(name: "LocalizationKit", package: "LocalizationKit"),
],
            path: "Sources/ConversationContextSizePlugin"
        ,
            resources: [.process("../../Resources/Localizable.xcstrings")])
    ]
)
