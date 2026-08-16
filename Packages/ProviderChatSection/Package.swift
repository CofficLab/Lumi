// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderChatSection",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderChatSection", targets: ["ProviderChatSection"]),
    ],
    dependencies: [
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "ProviderChatSection",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/ProviderChatSection"
        ),
        .testTarget(
            name: "ProviderChatSectionTests",
            dependencies: ["ProviderChatSection"]
        )
    ]
)
