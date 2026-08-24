// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginActivityHeatmap",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginActivityHeatmap", targets: ["PluginActivityHeatmap"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderSettingView"),
    ],
    targets: [
        .target(
            name: "PluginActivityHeatmap",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
            ]
        ),
        .testTarget(
            name: "PluginActivityHeatmapTests",
            dependencies: ["PluginActivityHeatmap"]
        ),
    ]
)
