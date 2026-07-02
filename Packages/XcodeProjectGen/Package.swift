// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XcodeProjectGen",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "XcodeProjectGen",
            targets: ["XcodeProjectGen"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tuist/XcodeProj", from: "9.11.0"),
    ],
    targets: [
        .target(
            name: "XcodeProjectGen",
            dependencies: [
                .product(name: "XcodeProj", package: "XcodeProj"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "XcodeProjectGenTests",
            dependencies: ["XcodeProjectGen"],
            path: "Tests"
        ),
    ]
)
