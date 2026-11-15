// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: .product(name: "ProviderConversation", package: "LumiProviders"),
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: .product(name: "ProviderConversation", package: "LumiProviders"),
            targets: ["ProviderConversation"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.24.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKitLLM.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKitTestSupport.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: .product(name: "ProviderConversation", package: "LumiProviders"),
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitLLM", package: "LumiKitLLM"),
                .product(name: "KitTestIsolation", package: "LumiKitTestSupport"),
            ],
            path: "Sources/ProviderConversation"
        ),
        .testTarget(
            name: "ProviderConversationTests",
            dependencies: ["ProviderConversation", .product(name: "KitTestSupport", package: "LumiKitTestSupport")]
        )
    ]
)
