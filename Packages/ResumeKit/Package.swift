// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ResumeKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ResumeKit", targets: ["ResumeKit"]),
    ],
    dependencies: [
        .package(path: "../HTMLPreviewKit"),
    ],
    targets: [
        .target(
            name: "ResumeKit",
            dependencies: [
                .product(name: "HTMLPreviewKit", package: "HTMLPreviewKit"),
            ]
        ),
        .testTarget(
            name: "ResumeKitTests",
            dependencies: ["ResumeKit"]
        ),
    ]
)
