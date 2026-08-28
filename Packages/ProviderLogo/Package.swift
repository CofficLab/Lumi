// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderLogo",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ProviderLogo",
            targets: ["ProviderLogo"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ProviderLogo",
            path: "Sources/ProviderLogo"
        ),
        .testTarget(
            name: "ProviderLogoTests",
            dependencies: ["ProviderLogo"]
        )
    ]
)
