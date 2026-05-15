// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WebFetchKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "WebFetchKit",
            targets: ["WebFetchKit"]
        )
    ],
    targets: [
        .target(
            name: "WebFetchKit",
            path: "Sources/WebFetchKit"
        ),
        .testTarget(
            name: "WebFetchKitTests",
            dependencies: ["WebFetchKit"],
            path: "Tests/WebFetchKitTests"
        )
    ]
)
