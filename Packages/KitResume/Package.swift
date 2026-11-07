// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitResume",
    platforms: [.macOS("13.1"), .iOS(.v17)],
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
