// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitFileSystem",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "KitFileSystem",
            targets: ["KitFileSystem"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
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
