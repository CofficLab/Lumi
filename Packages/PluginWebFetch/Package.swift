// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginWebFetch",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginWebFetch",
            targets: ["PluginWebFetch"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../SuperLogKit"),
        .package(path: "../WebFetchKit"),
    ],
    targets: [
        .target(
            name: "PluginWebFetch",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "WebFetchKit", package: "WebFetchKit"),
            ],
            path: "Sources/PluginWebFetch",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginWebFetchTests",
            dependencies: ["PluginWebFetch"],
            path: "Tests/PluginWebFetchTests"
        )
    ]
)
