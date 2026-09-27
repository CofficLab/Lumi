// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeManager",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PluginThemeManager",
            targets: ["PluginThemeManager"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "PluginThemeManager",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderTheme", package: "LumiProviders"),
            ]
        ),
        .testTarget(
            name: "PluginThemeManagerTests",
            dependencies: ["PluginThemeManager"]
        ),
    ]
)
