// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XcodeKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "XcodeKit",
            targets: ["XcodeKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tuist/XcodeProj", from: "9.11.0"),
        .package(path: "../SuperLogKit"),
        .package(path: "../LumiLocalizationKit"),
    ],
    targets: [
        .target(
            name: "XcodeKit",
            dependencies: [
                .product(name: "XcodeProj", package: "XcodeProj"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "XcodeKitTests",
            dependencies: ["XcodeKit"],
            path: "Tests"
        ),
    ]
)
