// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeviceInfoPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DeviceInfoPlugin",
            targets: ["DeviceInfoPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/DeviceMonitorKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "DeviceInfoPlugin",
            dependencies: [
                .product(name: "DeviceMonitorKit", package: "DeviceMonitorKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "DeviceInfoPluginTests",
            dependencies: ["DeviceInfoPlugin"],
            path: "Tests"
        )
    ]
)
