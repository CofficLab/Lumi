// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginChatPanel",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginChatPanel", targets: ["PluginChatPanel"])],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KernelCore"), .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderRailView"),
        .package(path: "../KitLocalization"),
    ],
    targets: [.target(name: "PluginChatPanel", dependencies: [
        .product(name: "KernelCore", package: "KernelCore"),
        .product(name: "KitLocalization", package: "KitLocalization"),
        .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
        .product(name: "ProviderChatSection", package: "ProviderChatSection"),
        .product(name: "ProviderContentView", package: "ProviderContentView"),
        .product(name: "ProviderRailView", package: "ProviderRailView"),
    ],
        resources: [.process("Resources/Localizable.xcstrings")]
    )]
)
