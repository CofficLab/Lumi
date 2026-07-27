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
        .package(path: "../LocalizationKit"),
    ],
    targets: [
        .target(
            name: "XcodeProjectGen",
            dependencies: [
                .product(name: "XcodeProj", package: "XcodeProj"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
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
