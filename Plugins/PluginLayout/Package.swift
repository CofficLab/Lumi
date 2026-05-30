// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLayout",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLayout",
            targets: ["PluginLayout"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLayout",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLayout",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLayoutTests",
            dependencies: ["PluginLayout"],
            path: "Tests/PluginLayoutTests"
        )
    ]
)
