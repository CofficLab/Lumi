// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginThemeManager",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PluginThemeManager",
            targets: ["PluginThemeManager"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiKernel"),
        .package(path: "../LumiLogging"),
        .package(path: "../LumiProviders"),
        .package(path: "../LumiLocalization"),
    ],
    targets: [
        .target(
            name: "PluginThemeManager",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderTheme", package: "LumiProviders"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginThemeManagerTests",
            dependencies: ["PluginThemeManager"]
        ),
    ]
)
