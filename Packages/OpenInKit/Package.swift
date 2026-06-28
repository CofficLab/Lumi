// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenInKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OpenInKit",
            targets: ["OpenInKit"]
        )
    ],
    targets: [
        .target(
            name: "OpenInKit",
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "OpenInKitTests",
            dependencies: ["OpenInKit"],
            path: "Tests"
        )
    ]
)
