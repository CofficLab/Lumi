// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppStoreConnect",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginAppStoreConnect",
            targets: ["PluginAppStoreConnect"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginAppStoreConnect",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginAppStoreConnect",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "PluginAppStoreConnectTests",
            dependencies: ["PluginAppStoreConnect"],
            path: "Tests/PluginAppStoreConnectTests"
        )
    ]
)
