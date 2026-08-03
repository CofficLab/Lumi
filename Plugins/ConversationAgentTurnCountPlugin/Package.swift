// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConversationAgentTurnCountPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "ConversationAgentTurnCountPlugin",
            targets: ["ConversationAgentTurnCountPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ConversationAgentTurnCountPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/ConversationAgentTurnCountPlugin"
        )
    ]
)
