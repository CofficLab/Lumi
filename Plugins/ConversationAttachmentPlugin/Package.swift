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
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ConversationAttachmentPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources"
        ),
    ]
)