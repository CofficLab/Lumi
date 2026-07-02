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
    dependencies: [
        .package(path: "../SuperLogKit")
    ],
    targets: [
        .target(
            name: "FileTreeKit",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit")
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "FileTreeKitTests",
            dependencies: ["FileTreeKit"],
            path: "Tests"
        )
    ]
)
