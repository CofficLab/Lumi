// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderChatSection",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderChatSection", targets: ["ProviderChatSection"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderConversation"),
    ],
    targets: [
        .target(
            name: "ProviderChatSection",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
            ],
            path: "Sources/ProviderChatSection"
        ),
        .testTarget(
            name: "ProviderChatSectionTests",
            dependencies: [
                "ProviderChatSection",
                .product(name: "ProviderConversation", package: "ProviderConversation"),
            ]
        )
    ]
)
