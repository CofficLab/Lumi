// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitDownload",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "KitDownload",
            targets: ["KitDownload"]
        ),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiLocalization"),
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
