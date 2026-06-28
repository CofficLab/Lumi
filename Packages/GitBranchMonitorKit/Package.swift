// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GitBranchMonitorKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GitBranchMonitorKit",
            targets: ["GitBranchMonitorKit"]
        )
    ],
    dependencies: [
        .package(path: "../SuperLogKit")
    ],
    targets: [
        .target(
            name: "GitBranchMonitorKit",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "GitBranchMonitorKitTests",
            dependencies: ["GitBranchMonitorKit"],
            path: "Tests"
        )
    ]
)
