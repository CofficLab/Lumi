// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderMessageRendering",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "ProviderMessageRendering", targets: ["ProviderMessageRendering"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.4"),
        .package(path: "../ProviderMessage"),
    ],
    targets: [
        .target(
            name: "ProviderMessageRendering",
            dependencies: [
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Sources/ProviderMessageRendering"
        ),
        .testTarget(
            name: "ProviderMessageRenderingTests",
            dependencies: ["ProviderMessageRendering"],
            path: "Tests/ProviderMessageRenderingTests"
        ),
    ]
)
