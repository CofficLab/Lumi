// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitDownload",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "KitDownload",
            targets: ["KitDownload"]
        ),
    ],
    dependencies: [
        .package(path: "../KitLocalization"),
    ],

    targets: [
        .target(
            name: "KitDownload",
            dependencies: [
                .product(name: "KitLocalization", package: "KitLocalization"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "KitDownloadTests",
            dependencies: ["KitDownload"],
            path: "Tests"
        ),
    ]
)
