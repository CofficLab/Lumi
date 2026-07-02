// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThemeDraculaPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ThemeDraculaPlugin",
            targets: ["ThemeDraculaPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "ThemeDraculaPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI")
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ThemeDraculaPluginTests",
            dependencies: ["ThemeDraculaPlugin"],
            path: "Tests"
        )
    ]
)
