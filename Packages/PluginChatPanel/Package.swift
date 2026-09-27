// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginChatPanel",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginChatPanel", targets: ["PluginChatPanel"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"), .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderStorage"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "PluginChatPanel", dependencies: [
            .product(name: "KernelCore", package: "LumiKernel"),
            .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
            .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            .product(name: "ProviderChatSection", package: "ProviderChatSection"),
            .product(name: "ProviderRootView", package: "ProviderRootView"),
            .product(name: "ProviderRailView", package: "ProviderRailView"),
            .product(name: "ProviderStorage", package: "ProviderStorage"),
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
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ]
        ),
    ]
)
