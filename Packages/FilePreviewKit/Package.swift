// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FilePreviewKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "FilePreviewKit",
            targets: ["FilePreviewKit"]
        )
    ],
    targets: [
        .target(
            name: "FilePreviewKit",
            path: ".",
            exclude: [
                "Package.swift",
                "README.md",
                "Tests"
            ],
            sources: [
                "FilePreviewView.swift"
            ]
        ),
        .testTarget(
            name: "FilePreviewKitTests",
            dependencies: ["FilePreviewKit"],
            path: "Tests/FilePreviewKitTests"
        )
    ]
)
