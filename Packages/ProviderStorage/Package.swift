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
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "ProviderStorage",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources/ProviderStorage"
        ),
        .testTarget(
            name: "ProviderStorageTests",
            dependencies: [
                "ProviderStorage",
                .product(name: "KernelCore", package: "KernelCore"),
            ]
        )
    ]
)
