// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderRailView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderRailView",
            targets: ["ProviderRailView"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "ProviderRailView",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/ProviderRailView"
        ),
        .testTarget(
            name: "ProviderRailViewTests",
            dependencies: ["ProviderRailView"]
        )
    ]
)
