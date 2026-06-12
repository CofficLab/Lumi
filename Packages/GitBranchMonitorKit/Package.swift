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
    targets: [
        .target(
            name: "GitBranchMonitorKit",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "GitBranchMonitorKitTests",
            dependencies: ["GitBranchMonitorKit"],
            path: "Tests"
        )
    ]
)
