// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HistoryDBStatusBarPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HistoryDBStatusBarPlugin",
            targets: ["HistoryDBStatusBarPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LumiChatKit"),
    ],
    targets: [
        .target(
            name: "HistoryDBStatusBarPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiChatKit", package: "LumiChatKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "HistoryDBStatusBarPluginTests",
            dependencies: [
                "HistoryDBStatusBarPlugin",
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Tests"
        )
    ]
)
