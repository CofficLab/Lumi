// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitLocalization",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "KitLocalization",
            targets: ["KitLocalization"]
        ),
    ],
    targets: [
        .target(
            name: "KitLocalization"
        ),
        .testTarget(
            name: "KitLocalizationTests",
            dependencies: ["KitLocalization"]
        ),
    ]
)
