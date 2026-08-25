// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderProject",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderProject",
            targets: ["ProviderProject"]
        ),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "ProviderProject",
            dependencies: [
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources/ProviderProject"
        ),
        .testTarget(
            name: "ProviderProjectTests",
            dependencies: ["ProviderProject"]
        )
    ]
)
