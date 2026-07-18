// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RAGKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "RAGKit",
            targets: ["RAGKit"]
        ),
    ],
    dependencies: [
        .package(path: "../LocalizationKit"),
    ],

    targets: [
        .target(
            name: "RAGKit",
            dependencies: [
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "RAGKitTests",
            dependencies: ["RAGKit"],
            path: "Tests"
        ),
    ]
)
