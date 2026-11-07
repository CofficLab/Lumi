// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitFileSystem",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "KitFileSystem",
            targets: ["KitFileSystem"]
        ),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiLocalization"),
    ],
    targets: [
        .target(
            name: "KitFileSystem",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
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
