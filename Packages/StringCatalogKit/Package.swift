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
    targets: [
        .target(
            name: "StringCatalogKit",
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
