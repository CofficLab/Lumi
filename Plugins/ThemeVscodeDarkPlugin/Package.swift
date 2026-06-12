// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThemeVscodeDarkPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ThemeVscodeDarkPlugin",
            targets: ["ThemeVscodeDarkPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "ThemeVscodeDarkPlugin",
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
            name: "ThemeVscodeDarkPluginTests",
            dependencies: ["ThemeVscodeDarkPlugin"],
            path: "Tests"
        )
    ]
)
