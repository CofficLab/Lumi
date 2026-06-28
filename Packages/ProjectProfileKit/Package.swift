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
    targets: [
        .target(
            name: "ProjectProfileKit",
            path: "Sources"
        ),
        .testTarget(
            name: "ProjectProfileKitTests",
            dependencies: ["ProjectProfileKit"],
            path: "Tests"
        ),
    ]
)
