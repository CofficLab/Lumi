// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MagicAlert",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MagicAlert",
            targets: ["MagicAlert"]
        )
    ],
    targets: [
        .target(
            name: "MagicAlert"
        )
    ]
)
