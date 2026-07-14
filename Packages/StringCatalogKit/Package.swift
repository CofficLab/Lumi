// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StringCatalogKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "StringCatalogKit",
            targets: ["StringCatalogKit"]
        )
    ],
    dependencies: [
        .package(path: "../LumiLocalizationKit"),
    ],

    targets: [
        .target(
            name: "StringCatalogKit",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "StringCatalogKitTests",
            dependencies: ["StringCatalogKit"],
            path: "Tests"
        )
    ]
)
