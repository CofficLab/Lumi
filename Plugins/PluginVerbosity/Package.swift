// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginVerbosity",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginVerbosity",
            targets: ["PluginVerbosity"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginVerbosity",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginVerbosity",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginVerbosityTests",
            dependencies: ["PluginVerbosity"],
            path: "Tests/PluginVerbosityTests"
        )
    ]
)
