// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitDownload",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "KitDownload",
            targets: ["KitDownload"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.1"),
    ],

    targets: [
        .target(
            name: "KitDownload",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/KitDownload",
            resources: [
                .process("../../Resources")
            ]
        ),
        .testTarget(
            name: "KitDownloadTests",
            dependencies: ["KitDownload"],
            path: "Tests"
        ),
    ]
)
