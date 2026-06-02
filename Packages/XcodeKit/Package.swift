// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XcodeKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "XcodeKit",
            targets: ["XcodeKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tuist/XcodeProj", from: "9.11.0"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "XcodeKit",
            path: "Sources"
            dependencies: [
                .product(name: "XcodeProj", package: "XcodeProj"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ]
        ),
        .testTarget(
            name: "XcodeKitTests",
            dependencies: ["XcodeKit"],
            path: "Tests"
        ),
    ]
)
