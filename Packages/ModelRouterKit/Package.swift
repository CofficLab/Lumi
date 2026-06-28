// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ModelRouterKit",
    defaultLocalization: "en",
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
            path: "Sources"
        ),
        .testTarget(
            name: "ModelRouterKitTests",
            dependencies: ["ModelRouterKit"],
            path: "Tests"
        ),
    ]
)
