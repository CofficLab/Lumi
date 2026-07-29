// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationReasoningPlugin",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConversationReasoningPlugin",
            targets: ["ConversationReasoningPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ConversationReasoningPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "ConversationReasoningPluginTests",
            dependencies: ["ConversationReasoningPlugin"],
            path: "Tests"
        )
    ]
)
