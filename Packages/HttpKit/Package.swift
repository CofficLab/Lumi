// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HttpKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HttpKit",
            targets: ["HttpKit"]
        ),
    ],
    targets: [
        .target(
            name: "HttpKit",
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "HttpKitTests",
            dependencies: ["HttpKit"],
            path: "Tests"
        ),
    ]
)
