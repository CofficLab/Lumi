// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectProfileKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ProjectProfileKit",
            targets: ["ProjectProfileKit"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiLocalizationKit"),
    ],

    targets: [
        .target(
            name: "ProjectProfileKit",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "ProjectProfileKitTests",
            dependencies: ["ProjectProfileKit"],
            path: "Tests"
        ),
    ]
)
