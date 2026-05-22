// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToolKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ToolKit",
            targets: ["ToolKit"]
        )
    ],
    dependencies: [
        .package(path: "../SuperLogKit")
    ],
    targets: [
        .target(
            name: "ToolKit",
            dependencies: ["SuperLogKit"],
            path: "Sources/ToolKit"
        ),
        .testTarget(
            name: "ToolKitTests",
            dependencies: ["ToolKit"],
            path: "Tests/ToolKitTests"
        )
    ]
)
