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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "ProviderStorage",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources/ProviderStorage"
        ),
        .testTarget(
            name: "ProviderStorageTests",
            dependencies: [
                "ProviderStorage",
                .product(name: "KernelCore", package: "LumiKernel"),
            ]
        )
    ]
)
