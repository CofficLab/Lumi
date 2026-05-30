// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginScreenshot",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginScreenshot",
            targets: ["PluginScreenshot"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginScreenshot",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginScreenshot"
        ),
        .testTarget(
            name: "PluginScreenshotTests",
            dependencies: ["PluginScreenshot"],
            path: "Tests/PluginScreenshotTests"
        )
    ]
)
