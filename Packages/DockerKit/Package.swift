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
    dependencies: [
        .package(path: "../ShellKit")
    ],
    targets: [
        .target(
            name: "DockerKit",
            dependencies: [
                .product(name: "ShellKit", package: "ShellKit")
            ],
            path: "Sources/DockerKit"
        ),
        .testTarget(
            name: "DockerKitTests",
            dependencies: ["DockerKit"],
            path: "Tests"
        )
    ]
)
