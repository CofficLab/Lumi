// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderChatSection",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "ProviderChatSection", targets: ["ProviderChatSection"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiUI"),
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
