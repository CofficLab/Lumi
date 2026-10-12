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
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.7"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../ProviderPerformanceMetrics"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginPerformanceMetrics",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderPerformanceMetrics", package: "ProviderPerformanceMetrics"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginPerformanceMetricsTests",
            dependencies: ["PluginPerformanceMetrics"]
        ),
    ]
)
