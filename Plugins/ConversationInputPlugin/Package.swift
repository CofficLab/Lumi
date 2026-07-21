// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationInputPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "ConversationInputPlugin",
            targets: ["ConversationInputPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiCoreChat"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ConversationInputPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiCoreChat", package: "LumiCoreChat"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/ConversationInputPlugin"
        )
    ]
)