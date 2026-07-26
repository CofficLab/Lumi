// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HttpKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HttpKit",
            targets: ["HttpKit"]
        ),
    ],
    dependencies: [
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit"),
    ],

    targets: [
        .target(
            name: "HttpKit",
            dependencies: [
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "HttpKitTests",
            dependencies: ["HttpKit"],
            path: "Tests"
        ),
    ]
)
