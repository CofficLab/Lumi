// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginSettingView",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17),
    ],
    products: [
        .library(name: "PluginSettingView", targets: ["PluginSettingView"]),
    ],
    dependencies: [
        .package(path: "../LumiKernel"),
        .package(path: "../LumiLocalization"),
        .package(path: "../LumiSettings"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginSettingView",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginSettingViewTests",
            dependencies: [
                "PluginSettingView",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
            ]
        ),
    ]
)
