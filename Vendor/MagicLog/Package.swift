// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MagicLog",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MagicLog",
            targets: ["MagicLog"]
        )
    ],
    targets: [
        .target(
            name: "MagicLog"
        ),
        .testTarget(
            name: "MagicLogTests",
            dependencies: ["MagicLog"]
        )
    ]
)