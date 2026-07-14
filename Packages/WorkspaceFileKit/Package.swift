// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WorkspaceFileKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "WorkspaceFileKit",
            targets: ["WorkspaceFileKit"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiLocalizationKit"),
    ],

    targets: [
        .target(
            name: "WorkspaceFileKit",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "WorkspaceFileKitTests",
            dependencies: ["WorkspaceFileKit"],
            path: "Tests"
        ),
    ]
)
