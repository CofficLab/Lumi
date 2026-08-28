// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderTheme",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderTheme",
            targets: ["ProviderTheme"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ProviderTheme",
            path: "Sources/ProviderTheme"
        ),
        .testTarget(
            name: "ProviderThemeTests",
            dependencies: ["ProviderTheme"]
        )
    ]
)
