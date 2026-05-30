// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginChatMode",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginChatMode",
            targets: ["PluginChatMode"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginChatMode",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginChatMode",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginChatModeTests",
            dependencies: ["PluginChatMode"],
            path: "Tests/PluginChatModeTests"
        )
    ]
)
