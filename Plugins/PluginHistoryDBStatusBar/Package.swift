// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginHistoryDBStatusBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginHistoryDBStatusBar",
            targets: ["PluginHistoryDBStatusBar"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginHistoryDBStatusBar",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginHistoryDBStatusBar",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginHistoryDBStatusBarTests",
            dependencies: ["PluginHistoryDBStatusBar"],
            path: "Tests/PluginHistoryDBStatusBarTests"
        )
    ]
)
