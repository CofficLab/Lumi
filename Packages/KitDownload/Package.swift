// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitDownload",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "KitDownload",
            targets: ["KitDownload"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],

    targets: [
        .target(
            name: "KitDownload",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
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
