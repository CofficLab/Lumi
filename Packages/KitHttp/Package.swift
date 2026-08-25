// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitHttp",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "KitHttp",
            targets: ["KitHttp"]
        ),
    ],
    dependencies: [
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog"),
    ],

    targets: [
        .target(
            name: "KitHttp",
            dependencies: [
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "KitHttpTests",
            dependencies: ["KitHttp"],
            path: "Tests"
        ),
    ]
)
