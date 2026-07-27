// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WebFetchKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "WebFetchKit",
            targets: ["WebFetchKit"]
        )
    ],
    dependencies: [
        .package(path: "../HttpKit"),
        .package(path: "../LocalizationKit"),
    ],
    targets: [
        .target(
            name: "WebFetchKit",
            dependencies: [
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "WebFetchKitTests",
            dependencies: ["WebFetchKit"],
            path: "Tests"
        )
    ]
)
