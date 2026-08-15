// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderWindow",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderWindow",
            targets: ["ProviderWindow"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ProviderWindow",
            path: "Sources/ProviderWindow"
        ),
        .testTarget(
            name: "ProviderWindowTests",
            dependencies: ["ProviderWindow"]
        )
    ]
)
