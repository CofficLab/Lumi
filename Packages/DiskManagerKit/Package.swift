// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiskManagerKit",
    defaultLocalization: "en",
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
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "DiskManagerKitTests",
            dependencies: ["DiskManagerKit"],
            path: "Tests"
        )
    ]
)
