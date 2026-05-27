// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HTMLPreviewKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HTMLPreviewKit",
            targets: ["HTMLPreviewKit"]
        )
    ],
    targets: [
        .target(
            name: "HTMLPreviewKit",
            path: "Sources/HTMLPreviewKit"
        ),
        .testTarget(
            name: "HTMLPreviewKitTests",
            dependencies: ["HTMLPreviewKit"],
            path: "Tests/HTMLPreviewKitTests"
        )
    ]
)
