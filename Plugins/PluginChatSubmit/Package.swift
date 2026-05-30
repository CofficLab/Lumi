// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginChatSubmit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginChatSubmit",
            targets: ["PluginChatSubmit"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginChatSubmit",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginChatSubmit"
        ),
        .testTarget(
            name: "PluginChatSubmitTests",
            dependencies: ["PluginChatSubmit"],
            path: "Tests/PluginChatSubmitTests"
        )
    ]
)
