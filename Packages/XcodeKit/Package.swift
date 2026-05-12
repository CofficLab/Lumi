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
        .package(url: "https://github.com/CofficLab/MagicKit", from: "1.5.23"),
    ],
    targets: [
        .target(
            name: "XcodeKit",
            dependencies: [
                .product(name: "XcodeProj", package: "XcodeProj"),
                .product(name: "MagicKit", package: "MagicKit"),
            ]
        ),
        .testTarget(
            name: "XcodeKitTests",
            dependencies: ["XcodeKit"]
        ),
    ]
)
