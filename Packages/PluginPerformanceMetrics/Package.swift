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
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
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
                .product(name: "LumiUI", package: "LumiUI"),
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
