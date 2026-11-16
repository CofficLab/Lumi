// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderMessage",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "ProviderMessage", targets: ["ProviderMessage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.24.0"),
    ],
    targets: [
        .target(
            name: "ProviderMessage",
            dependencies: [.product(name: "ProviderConversation", package: "LumiProviders")],
            path: "Sources/ProviderMessage"
        ),
        .testTarget(
            name: "ProviderMessageTests",
            dependencies: ["ProviderMessage"]
        )
    ]
)
