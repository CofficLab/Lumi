// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderWebServer",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderWebServer",
            targets: ["ProviderWebServer"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ProviderWebServer",
            path: "Sources/ProviderWebServer"
        ),
        .testTarget(
            name: "ProviderWebServerTests",
            dependencies: ["ProviderWebServer"]
        )
    ]
)
