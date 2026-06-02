// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SuperLogKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SuperLogKit",
            targets: ["SuperLogKit"]
        )
    ],
    targets: [
        .target(
            name: "SuperLogKit",
            path: "Sources/SuperLogKit"
        ),
        .testTarget(
            name: "SuperLogKitTests",
            dependencies: ["SuperLogKit"],
            path: "Tests"
        )
    ]
)
