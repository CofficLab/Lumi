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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
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
