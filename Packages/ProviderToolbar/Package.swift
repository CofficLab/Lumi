// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderToolbar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderToolbar",
            targets: ["ProviderToolbar"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ProviderToolbar",
            path: "Sources/ProviderToolbar"
        ),
        .testTarget(
            name: "ProviderToolbarTests",
            dependencies: ["ProviderToolbar"]
        )
    ]
)
