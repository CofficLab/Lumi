// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitResume",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KitResume", targets: ["KitResume"]),
    ],
    dependencies: [
        .package(path: "../KitHTMLPreview"),
    ],
    targets: [
        .target(
            name: "KitResume",
            dependencies: [
                .product(name: "KitHTMLPreview", package: "KitHTMLPreview"),
            ]
        ),
        .testTarget(
            name: "KitResumeTests",
            dependencies: ["KitResume"]
        ),
    ]
)
