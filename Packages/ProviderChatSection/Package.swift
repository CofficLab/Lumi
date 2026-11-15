// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: .product(name: "ProviderChatSection", package: "LumiProviders"),
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "ProviderChatSection", targets: ["ProviderChatSection"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.24.0"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.13.0"),
    ],
    targets: [
        .target(
            name: .product(name: "ProviderChatSection", package: "LumiProviders"),
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
            ],
            path: "Sources/ProviderChatSection"
        ),
        .testTarget(
            name: "ProviderChatSectionTests",
            dependencies: [
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
            ]
        )
    ]
)
