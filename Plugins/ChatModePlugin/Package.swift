// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatModePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ChatModePlugin",
            targets: ["ChatModePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ChatModePlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ChatModePluginTests",
            dependencies: [
                "ChatModePlugin",
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Tests"
        )
    ]
)
