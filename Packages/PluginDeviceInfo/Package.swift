// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDeviceInfo",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginDeviceInfo",
            targets: ["PluginDeviceInfo"]
        )
    ],
    dependencies: [
        .package(path: "../DeviceMonitorKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginDeviceInfo",
            dependencies: [
                .product(name: "DeviceMonitorKit", package: "DeviceMonitorKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginDeviceInfo",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "PluginDeviceInfoTests",
            dependencies: ["PluginDeviceInfo"],
            path: "Tests/PluginDeviceInfoTests"
        )
    ]
)
