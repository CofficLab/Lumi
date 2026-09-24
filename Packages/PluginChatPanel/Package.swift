// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginChatPanel",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginChatPanel", targets: ["PluginChatPanel"])],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"), .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(name: "PluginChatPanel", dependencies: [
            .product(name: "KernelCore", package: "LumiKernel"),
            .product(name: "KitLocalization", package: "KitLocalization"),
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
