// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DatabaseKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DatabaseKit",
            targets: ["DatabaseKit"]
        )
    ],
    targets: [
        .target(
            name: "DatabaseKit"
        ),
        .testTarget(
            name: "DatabaseKitTests",
            dependencies: ["DatabaseKit"]
        )
    ]
)
