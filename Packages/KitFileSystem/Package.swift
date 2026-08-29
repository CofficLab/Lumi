// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitFileSystem",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "KitFileSystem",
            targets: ["KitFileSystem"]
        ),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "KitFileSystem",
            dependencies: [
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "KitLocalization", package: "KitLocalization"),
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
