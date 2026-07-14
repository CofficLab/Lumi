// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiskManagerKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DiskManagerKit",
            targets: ["DiskManagerKit"]
        )
    ],
    dependencies: [
        .package(path: "../SuperLogKit")
        .package(path: "../LumiLocalizationKit"),
    ],
    targets: [
        .target(
            name: "DiskManagerKit",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit")
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "DiskManagerKitTests",
            dependencies: ["DiskManagerKit"],
            path: "Tests"
        )
    ]
)
