// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderMenuBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ProviderMenuBar",
            targets: ["ProviderMenuBar"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ProviderMenuBar",
            path: "Sources/ProviderMenuBar"
        ),
        .testTarget(
            name: "ProviderMenuBarTests",
            dependencies: ["ProviderMenuBar"]
        )
    ]
)
