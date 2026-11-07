// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderConversation",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderConversation",
            targets: ["ProviderConversation"]
        ),
    ],
    dependencies: [
        .package(path: "../KitLLM"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../KitTestSupport"),
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
