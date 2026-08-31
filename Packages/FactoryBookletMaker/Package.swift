// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FactoryBookletMaker",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FactoryBookletMaker", targets: ["FactoryBookletMaker"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../PluginActivityBar"),
        .package(name: "PluginBookletMaker", path: "../PluginBookletMaker"),
        .package(path: "../PluginCommand"),
        .package(path: "../PluginLogoCoffic"),
        .package(path: "../PluginLogoManager"),
        .package(path: "../PluginSettingView"),
        .package(path: "../PluginStorage"),
        .package(path: "../PluginThemePack"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderCommand"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderLogo"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderTheme"),
        .package(path: "../ProviderToolbar"),
    ],
    targets: [
        .target(
            name: "FactoryBookletMaker",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "PluginActivityBar", package: "PluginActivityBar"),
                .product(name: "PluginBookletMaker", package: "PluginBookletMaker"),
                .product(name: "PluginCommand", package: "PluginCommand"),
                .product(name: "PluginLogoCoffic", package: "PluginLogoCoffic"),
                .product(name: "PluginLogoManager", package: "PluginLogoManager"),
                .product(name: "PluginSettingView", package: "PluginSettingView"),
                .product(name: "PluginStorage", package: "PluginStorage"),
                .product(name: "PluginThemePack", package: "PluginThemePack"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderCommand", package: "ProviderCommand"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderLogo", package: "ProviderLogo"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderTheme", package: "ProviderTheme"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ],
            path: "Sources/FactoryBookletMaker",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "FactoryBookletMakerTests",
            dependencies: ["FactoryBookletMaker"],
            path: "Tests/FactoryBookletMakerTests"
        ),
    ]
)
