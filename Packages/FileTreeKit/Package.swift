// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FileTreeKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "FileTreeKit",
            targets: ["FileTreeKit"]
        )
    ],
    targets: [
        .target(
            name: "FileTreeKit"
            path: "Sources"
        ),
        .testTarget(
            name: "FileTreeKitTests",
            dependencies: ["FileTreeKit"],
            path: "Tests"
        )
    ]
)
