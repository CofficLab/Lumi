// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenInKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OpenInKit",
            targets: ["OpenInKit"]
        )
    ],
    targets: [
        .target(
            name: "OpenInKit",
            path: "Sources/OpenInKit"
        ),
        .testTarget(
            name: "OpenInKitTests",
            dependencies: ["OpenInKit"],
            path: "Tests/OpenInKitTests"
        )
    ]
)
