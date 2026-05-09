// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DockerKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DockerKit",
            targets: ["DockerKit"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DockerKit",
            path: "Sources/DockerKit"
        ),
        .testTarget(
            name: "DockerKitTests",
            dependencies: ["DockerKit"],
            path: "Tests/DockerKitTests"
        )
    ]
)
