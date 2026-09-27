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
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "KitSuperLog",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "KitSuperLogTests",
            dependencies: ["KitSuperLog"],
            path: "Tests"
        )
    ]
)
