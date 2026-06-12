// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThemeVscodeLightPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ThemeVscodeLightPlugin",
            targets: ["ThemeVscodeLightPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "ThemeVscodeLightPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI")
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ThemeVscodeLightPluginTests",
            dependencies: ["ThemeVscodeLightPlugin"],
            path: "Tests"
        )
    ]
)
