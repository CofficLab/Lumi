// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginTextActions",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "PluginTextActions", targets: ["TextActionsPlugin"])
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../KitLLM"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../../Vendor/LumiSettings"),
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../KitTestSupport"),
    ],
    targets: [
        .target(
            name: "TextActionsPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ],
            path: "Sources/PluginTextActions",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "TextActionsPluginTests",
            dependencies: [
                "TextActionsPlugin",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "KitTestSupport", package: "KitTestSupport"),
            ],
            path: "Tests"
        )
    ]
)
