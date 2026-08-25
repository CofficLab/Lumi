// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderToolManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderToolManager",
            targets: ["ProviderToolManager"]
        ),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
    ],
    targets: [
        .target(
            name: "ProviderToolManager",
            dependencies: [
                .product(name: "KitAgentTool", package: "KitAgentTool"),
            ],
            path: "Sources/ProviderToolManager"
        ),
        .testTarget(
            name: "ProviderToolManagerTests",
            dependencies: ["ProviderToolManager"],
            path: "Tests/ProviderToolManagerTests"
        )
    ]
)
