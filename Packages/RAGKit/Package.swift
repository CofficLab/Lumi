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
        .package(path: "../LumiLocalizationKit"),
    ],

    targets: [
        .target(
            name: "RAGKit",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
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
