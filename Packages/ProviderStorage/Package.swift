// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderStorage",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderStorage",
            targets: ["ProviderStorage"]
        ),
    ],
    dependencies: [
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ProviderStorage",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/ProviderStorage"
        ),
        .testTarget(
            name: "ProviderStorageTests",
            dependencies: ["ProviderStorage"]
        )
    ]
)
