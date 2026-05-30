// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInXcode",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginOpenInXcode",
            targets: ["PluginOpenInXcode"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginOpenInXcode",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginOpenInXcode",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginOpenInXcodeTests",
            dependencies: ["PluginOpenInXcode"],
            path: "Tests/PluginOpenInXcodeTests"
        )
    ]
)
