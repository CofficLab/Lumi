// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderActivityBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderActivityBar",
            targets: ["ProviderActivityBar"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ProviderActivityBar",
            path: "Sources/ProviderActivityBar"
        ),
        .testTarget(
            name: "ProviderActivityBarTests",
            dependencies: ["ProviderActivityBar"]
        )
    ]
)
