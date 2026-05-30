// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginFontConfig",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginFontConfig",
            targets: ["PluginFontConfig"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginFontConfig",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginFontConfig",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginFontConfigTests",
            dependencies: ["PluginFontConfig"],
            path: "Tests/PluginFontConfigTests"
        )
    ]
)
