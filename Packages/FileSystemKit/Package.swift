// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FileSystemKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "FileSystemKit",
            targets: ["FileSystemKit"]
        ),
    ],
    dependencies: [
        .package(path: "../SuperLogKit"),
        .package(path: "../LocalizationKit"),
    ],
    targets: [
        .target(
            name: "FileSystemKit",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources/FileSystemKit",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "FileSystemKitTests",
            dependencies: ["FileSystemKit"],
            path: "Tests"
        ),
    ]
)
