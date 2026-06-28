// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SuperLogKit",
    defaultLocalization: "en",
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
            path: "Sources"
        ),
        .testTarget(
            name: "SuperLogKitTests",
            dependencies: ["SuperLogKit"],
            path: "Tests"
        )
    ]
)
