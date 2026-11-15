// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderConversation",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderConversation",
            targets: ["ProviderConversation"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/KitLLM.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/KitTestSupport.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "ProviderConversation",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ],
            path: "Sources/ProviderConversation"
        ),
        .testTarget(
            name: "ProviderConversationTests",
            dependencies: ["ProviderConversation", .product(name: "KitTestSupport", package: "KitTestSupport")]
        )
    ]
)
