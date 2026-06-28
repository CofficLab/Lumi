// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DownloadKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "DownloadKit",
            targets: ["DownloadKit"]
        ),
    ],
    targets: [
        .target(
            name: "DownloadKit",
            path: "Sources"
        ),
        .testTarget(
            name: "DownloadKitTests",
            dependencies: ["DownloadKit"],
            path: "Tests"
        ),
    ]
)
