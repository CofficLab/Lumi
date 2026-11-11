// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitHttp",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "KitHttp",
            targets: ["KitHttp"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.1"),
    ],

    targets: [
        .target(
            name: "KitHttp",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/KitHttp",
            resources: [
                .process("../../Resources")
            ]
        ),
        .testTarget(
            name: "KitHttpTests",
            dependencies: ["KitHttp"],
            path: "Tests"
        ),
    ]
)
