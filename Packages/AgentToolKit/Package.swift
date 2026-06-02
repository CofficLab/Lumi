// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentToolKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AgentToolKit",
            targets: ["AgentToolKit"]
        )
    ],
    dependencies: [
        .package(path: "../SuperLogKit")
    ],
    targets: [
        .target(
            name: "AgentToolKit",
            dependencies: ["SuperLogKit"],
            path: "Sources/AgentToolKit"
        ),
        .testTarget(
            name: "AgentToolKitTests",
            dependencies: ["AgentToolKit"],
            path: "Tests"
        )
    ]
)
