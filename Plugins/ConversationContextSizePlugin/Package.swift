// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationContextSizePlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "ConversationContextSizePlugin",
            targets: ["ConversationContextSizePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ConversationContextSizePlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/ConversationContextSizePlugin"
        )
    ]
)
