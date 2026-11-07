// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginChatPanel",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [.library(name: "PluginChatPanel", targets: ["PluginChatPanel"])],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../../Vendor/LumiLocalization"),
    ],
    targets: [
        .target(name: "PluginChatPanel", dependencies: [
            .product(name: "KernelCore", package: "LumiKernel"),
            .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            .product(name: "ProviderActivityBar", package: "LumiProviders"),
            .product(name: "ProviderToolbar", package: "LumiProviders"),
            .product(name: "ProviderChatSection", package: "ProviderChatSection"),
            .product(name: "ProviderRootView", package: "LumiProviders"),
            .product(name: "ProviderRailView", package: "LumiProviders"),
            .product(name: "ProviderStorage", package: "LumiProviders"),
        ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginChatPanelTests",
            dependencies: [
                "PluginChatPanel",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
            ]
        ),
    ]
)
