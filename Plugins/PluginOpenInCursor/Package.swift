// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInCursor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginOpenInCursor",
            targets: ["PluginOpenInCursor"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginOpenInCursor",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginOpenInCursor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginOpenInCursorTests",
            dependencies: ["PluginOpenInCursor"],
            path: "Tests/PluginOpenInCursorTests"
        )
    ]
)
