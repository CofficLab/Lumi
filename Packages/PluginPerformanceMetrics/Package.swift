// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginPerformanceMetrics",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginPerformanceMetrics", targets: ["PluginPerformanceMetrics"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderPerformanceMetrics"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginPerformanceMetrics",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "ProviderPerformanceMetrics", package: "ProviderPerformanceMetrics"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginPerformanceMetricsTests",
            dependencies: ["PluginPerformanceMetrics"]
        ),
    ]
)
