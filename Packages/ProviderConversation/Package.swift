// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderConversation",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKitLLM.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiKitTestSupport.git", from: "1.0.1"),
    ],
    targets: [
        .testTarget(
            name: "ProviderConversationTests",
            dependencies: [
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "KitLLM", package: "LumiKitLLM"),
                .product(name: "KitTestSupport", package: "LumiKitTestSupport"),
            ]
        )
    ]
)
