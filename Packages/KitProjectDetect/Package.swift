// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitProjectDetect",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "KitProjectDetect",
            targets: ["KitProjectDetect"]
        ),
    ],
    targets: [
        .target(
            name: "KitProjectDetect",
            path: "Sources/KitProjectDetect"
        ),
        .testTarget(
            name: "KitProjectDetectTests",
            dependencies: ["KitProjectDetect"],
            path: "Tests/KitProjectDetectTests"
        ),
    ]
)
