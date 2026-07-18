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
    dependencies: [
        .package(path: "../LocalizationKit"),
    ],

    targets: [
        .target(
            name: "DownloadKit",
            dependencies: [
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "DownloadKitTests",
            dependencies: ["DownloadKit"],
            path: "Tests"
        ),
    ]
)
