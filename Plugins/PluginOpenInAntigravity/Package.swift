// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInAntigravity",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginOpenInAntigravity",
            targets: ["PluginOpenInAntigravity"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginOpenInAntigravity",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginOpenInAntigravity",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginOpenInAntigravityTests",
            dependencies: ["PluginOpenInAntigravity"],
            path: "Tests"
        )
    ]
)
