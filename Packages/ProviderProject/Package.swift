// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderProject",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderProject",
            targets: ["ProviderProject"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ProviderProject",
            path: "Sources/ProviderProject"
        ),
        .testTarget(
            name: "ProviderProjectTests",
            dependencies: ["ProviderProject"]
        )
    ]
)
