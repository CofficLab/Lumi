// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginRequestLog",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginRequestLog",
            targets: ["PluginRequestLog"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/HttpKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginRequestLog",
            dependencies: [
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginRequestLog",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginRequestLogTests",
            dependencies: ["PluginRequestLog"],
            path: "Tests"
        )
    ]
)
