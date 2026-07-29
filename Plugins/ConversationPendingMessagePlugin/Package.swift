// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationPendingMessagePlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ConversationPendingMessagePlugin", targets: ["ConversationPendingMessagePlugin"])
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "ConversationPendingMessagePlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI")
            ],
            path: "Sources"
        )
    ]
)
