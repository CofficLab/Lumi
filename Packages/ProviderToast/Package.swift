// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderToast",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderToast",
            targets: ["ProviderToast"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ProviderToast",
            path: "Sources/ProviderToast"
        ),
        .testTarget(
            name: "ProviderToastTests",
            dependencies: ["ProviderToast"]
        )
    ]
)
