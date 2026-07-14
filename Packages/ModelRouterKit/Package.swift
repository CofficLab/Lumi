// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ModelRouterKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ModelRouterKit",
            targets: ["ModelRouterKit"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiLocalizationKit"),
    ],
    targets: [
        .target(
            name: "ModelRouterKit",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "ModelRouterKitTests",
            dependencies: ["ModelRouterKit"],
            path: "Tests"
        ),
    ]
)
