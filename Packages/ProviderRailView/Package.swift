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
        .package(path: "../LumiUI"),
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
