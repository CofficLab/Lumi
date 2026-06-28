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
    ],
    targets: [
        .target(
            name: "GitHubKit",
            dependencies: ["HttpKit"],
            path: "Sources"
        ),
        .testTarget(
            name: "GitHubKitTests",
            dependencies: ["GitHubKit"],
            path: "Tests"
        ),
    ]
)
