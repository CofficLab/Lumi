// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationMessageCountPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "ConversationMessageCountPlugin",
            targets: ["ConversationMessageCountPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ConversationMessageCountPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                        .product(name: "LocalizationKit", package: "LocalizationKit"),
],
            path: "Sources/ConversationMessageCountPlugin"
        ,
            resources: [.process("../../Resources/Localizable.xcstrings")])
    ]
)