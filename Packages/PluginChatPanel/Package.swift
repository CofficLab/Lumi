// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginChatPanel",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginChatPanel", targets: ["PluginChatPanel"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.7"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"), .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderChatSection"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "PluginChatPanel", dependencies: [
            .product(name: "KernelCore", package: "LumiKernel"),
            .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
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
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
            ]
        ),
    ]
)
