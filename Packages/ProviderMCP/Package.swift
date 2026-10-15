// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderMCP",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ProviderMCP", targets: ["ProviderMCP"]),
    ],
    dependencies: [
        .package(path: "../KitMCP"),
    ],
    targets: [
        .target(
            name: "ProviderMCP",
            dependencies: [
                .product(name: "KitMCP", package: "KitMCP"),
            ],
            path: "Sources/ProviderMCP"
        ),
        .testTarget(
            name: "ProviderMCPTests",
            dependencies: [
                "ProviderMCP",
                .product(name: "KitMCP", package: "KitMCP"),
            ],
            path: "Tests/ProviderMCPTests"
        ),
    ]
)
