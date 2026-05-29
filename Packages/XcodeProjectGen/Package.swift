// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XcodeProjectGen",
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
            path: "Sources/XcodeProjectGen"
        ),
        .testTarget(
            name: "XcodeProjectGenTests",
            dependencies: ["XcodeProjectGen"],
            path: "Tests/XcodeProjectGenTests"
        ),
    ]
)
