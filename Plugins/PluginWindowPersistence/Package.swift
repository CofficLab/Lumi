// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginWindowPersistence",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginWindowPersistence",
            targets: ["PluginWindowPersistence"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginWindowPersistence",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginWindowPersistence"
        ),
        .testTarget(
            name: "PluginWindowPersistenceTests",
            dependencies: ["PluginWindowPersistence"],
            path: "Tests"
        )
    ]
)
