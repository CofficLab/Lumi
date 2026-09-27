// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitFileSystem",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "KitFileSystem",
            targets: ["KitFileSystem"]
        ),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "KitFileSystem",
            dependencies: [
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/KitFileSystem",
            resources: [
                .process("../../Resources")
            ]
        ),
        .testTarget(
            name: "KitFileSystemTests",
            dependencies: ["KitFileSystem"],
            path: "Tests"
        ),
    ]
)
