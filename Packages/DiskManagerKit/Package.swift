// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiskManagerKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DiskManagerKit",
            targets: ["DiskManagerKit"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DiskManagerKit",
            path: "Sources/DiskManagerKit"
        ),
        .testTarget(
            name: "DiskManagerKitTests",
            dependencies: ["DiskManagerKit"],
            path: "Tests"
        )
    ]
)
