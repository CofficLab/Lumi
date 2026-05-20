// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectProfileKit",
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
            path: "Sources/ProjectProfileKit"
        ),
        .testTarget(
            name: "ProjectProfileKitTests",
            dependencies: ["ProjectProfileKit"],
            path: "Tests/ProjectProfileKitTests"
        ),
    ]
)
