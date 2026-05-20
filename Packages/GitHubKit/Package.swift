// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GitHubKit",
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
            path: "Sources/GitHubKit"
        ),
    ]
)
