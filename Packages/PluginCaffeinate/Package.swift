// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCaffeinate",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginCaffeinate", targets: ["PluginCaffeinate"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../KitAgentTool"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../../Vendor/LumiLogging"),
    ],
    targets: [
        .target(
            name: "PluginCaffeinate",
            dependencies: [
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderLogo", package: "LumiProviders"),
                .product(name: "ProviderMenuBar", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                "ProviderToolManager",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginCaffeinateTests",
            dependencies: [
                "PluginCaffeinate",
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderMenuBar", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
            ]
        ),
    ]
)
