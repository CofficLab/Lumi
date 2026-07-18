// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GitHubKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "GitHubKit",
            targets: ["GitHubKit"]
        ),
    ],
    dependencies: [
        .package(path: "../HttpKit"),
        .package(path: "../LocalizationKit"),
    ],
    targets: [
        .target(
            name: "GitHubKit",
            dependencies: ["HttpKit", .product(name: "LocalizationKit", package: "LocalizationKit")],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "GitHubKitTests",
            dependencies: ["GitHubKit"],
            path: "Tests"
        ),
    ]
)
