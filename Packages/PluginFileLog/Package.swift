// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginFileLog",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginFileLog",
            targets: ["PluginFileLog"]
        )
    ],
    dependencies: [
        .package(path: "../LumiCoreKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginFileLog",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginFileLog"
        ),
        .testTarget(
            name: "PluginFileLogTests",
            dependencies: ["PluginFileLog"],
            path: "Tests/PluginFileLogTests"
        )
    ]
)
