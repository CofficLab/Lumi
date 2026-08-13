// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationAttachmentPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConversationAttachmentPlugin",
            targets: ["ConversationAttachmentPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ConversationAttachmentPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                        .product(name: "LocalizationKit", package: "LocalizationKit"),
],
            path: "Sources"
        ,
            resources: [.process("../Resources/Localizable.xcstrings")]),
    ]
)