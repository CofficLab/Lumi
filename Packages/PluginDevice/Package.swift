// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDevice",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginDevice",
            targets: ["PluginDevice"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderSettingView"),
    ],
    targets: [
        .target(
            name: "PluginDevice",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
            ],
            path: "Sources/PluginDevice"
        ),
        .testTarget(
            name: "PluginDeviceTests",
            dependencies: ["PluginDevice"]
        )
    ]
)
