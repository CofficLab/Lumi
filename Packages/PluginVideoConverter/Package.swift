// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginVideoConverter",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginVideoConverter",
            targets: ["PluginVideoConverter"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginVideoConverter",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources/PluginVideoConverter",
            resources: [
                .process("../../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "PluginVideoConverterTests",
            dependencies: [
                "PluginVideoConverter",
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
            ]
        )
    ]
)
