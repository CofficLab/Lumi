// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderDocsView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderDocsView",
            targets: ["ProviderDocsView"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ProviderDocsView",
            path: "Sources/ProviderDocsView"
        ),
        .testTarget(
            name: "ProviderDocsViewTests",
            dependencies: ["ProviderDocsView"]
        )
    ]
)
