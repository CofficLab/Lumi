// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderNetwork",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderNetwork",
            targets: ["ProviderNetwork"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ProviderNetwork",
            path: "Sources/ProviderNetwork"
        ),
        .testTarget(
            name: "ProviderNetworkTests",
            dependencies: ["ProviderNetwork"]
        )
    ]
)
