// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WorkspaceFileKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "WorkspaceFileKit",
            targets: ["WorkspaceFileKit"]
        ),
    ],
    targets: [
        .target(
            name: "WorkspaceFileKit",
            path: "Sources"
        ),
        .testTarget(
            name: "WorkspaceFileKitTests",
            dependencies: ["WorkspaceFileKit"],
            path: "Tests"
        ),
    ]
)
