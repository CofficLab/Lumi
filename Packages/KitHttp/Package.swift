// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitHttp",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "KitHttp",
            targets: ["KitHttp"]
        ),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiLogging"),
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
