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
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
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