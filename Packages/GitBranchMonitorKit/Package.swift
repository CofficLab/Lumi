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
        .package(path: "../SuperLogKit"),
        .package(path: "../LocalizationKit"),
    ],
    targets: [
        .target(
            name: "GitBranchMonitorKit",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "GitBranchMonitorKitTests",
            dependencies: ["GitBranchMonitorKit"],
            path: "Tests"
        )
    ]
)
