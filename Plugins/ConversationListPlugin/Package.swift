// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConversationListPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConversationListPlugin",
            targets: ["ConversationListPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiChatKit"),
    ],
    targets: [
        .target(
            name: "ConversationListPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: ".",
            exclude: [
                "Tests",
                "README.md",
                "Sources/Views",
                "Sources/Tools/CreateNewConversationTool.swift",
                "Sources/Tools/DeleteConversationTool.swift",
                "Sources/Tools/GetConversationCountTool.swift",
                "Sources/Tools/GetRecentConversationsTool.swift",
                "Sources/Tools/SetConversationProjectTool.swift",
            ],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ConversationListPluginTests",
            dependencies: [
                "ConversationListPlugin",
                .product(name: "LumiChatKit", package: "LumiChatKit"),
            ],
            path: "Tests"
        )
    ]
)
