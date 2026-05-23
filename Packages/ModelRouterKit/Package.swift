// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ModelRouterKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ModelRouterKit",
            targets: ["ModelRouterKit"]
        ),
    ],
    targets: [
        .target(
            name: "ModelRouterKit",
            path: "Sources/ModelRouterKit"
        ),
        .testTarget(
            name: "ModelRouterKitTests",
            dependencies: ["ModelRouterKit"],
            path: "Tests/ModelRouterKitTests"
        ),
    ]
)
