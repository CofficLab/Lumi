// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThemeStatusBarPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ThemeStatusBarPlugin",
            targets: ["ThemeStatusBarPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "ThemeStatusBarPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ThemeStatusBarPluginTests",
            dependencies: ["ThemeStatusBarPlugin"],
            path: "Tests"
        )
    ]
)
