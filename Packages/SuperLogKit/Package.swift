// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SuperLogKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SuperLogKit",
            targets: ["SuperLogKit"]
        )
    ],
    dependencies: [
        .package(path: "../LumiLocalizationKit"),
    ],
    targets: [
        .target(
            name: "SuperLogKit",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "SuperLogKitTests",
            dependencies: ["SuperLogKit"],
            path: "Tests"
        )
    ]
)
