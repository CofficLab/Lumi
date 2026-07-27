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
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/EditorChatInputKit"),
    ],
    targets: [
        .target(
            name: "ConversationInputPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "EditorChatInputKit", package: "EditorChatInputKit"),
            ],
            path: "Sources/ConversationInputPlugin"
        )
    ]
)