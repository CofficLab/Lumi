// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginBrowser",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginBrowser",
            targets: ["PluginBrowser"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginBrowser",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginBrowser",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginBrowserTests",
            dependencies: ["PluginBrowser"],
            path: "Tests/PluginBrowserTests"
        )
    ]
)
