// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderChatSection",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
    ],
    targets: [
        .testTarget(
            name: "ProviderChatSectionTests",
            dependencies: [
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
            ]
        )
    ]
)
