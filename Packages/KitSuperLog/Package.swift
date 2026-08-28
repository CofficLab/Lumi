// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitSuperLog",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "KitSuperLog",
            targets: ["KitSuperLog"]
        )
    ],
    dependencies: [
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "KitSuperLog",
            dependencies: [
                .product(name: "KitLocalization", package: "KitLocalization"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "KitSuperLogTests",
            dependencies: ["KitSuperLog"],
            path: "Tests"
        )
    ]
)
