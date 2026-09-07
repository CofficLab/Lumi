// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FactoryBookletMaker",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "FactoryBookletMakerMac", targets: ["FactoryBookletMakerMac"]),
        .library(name: "FactoryBookletMakerIOS", targets: ["FactoryBookletMakerIOS"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
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
            name: "FactoryBookletMakerMac",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "PluginBookletMaker", package: "PluginBookletMaker"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderTheme", package: "ProviderTheme"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "PluginActivityBar", package: "PluginActivityBar", condition: .when(platforms: [.macOS])),
                .product(name: "PluginCommand", package: "PluginCommand", condition: .when(platforms: [.macOS])),
                .product(name: "PluginLogoCoffic", package: "PluginLogoCoffic", condition: .when(platforms: [.macOS])),
                .product(name: "PluginLogoManager", package: "PluginLogoManager", condition: .when(platforms: [.macOS])),
                .product(name: "PluginSettingView", package: "PluginSettingView", condition: .when(platforms: [.macOS])),
                .product(name: "PluginStorage", package: "PluginStorage", condition: .when(platforms: [.macOS])),
                .product(name: "PluginThemePack", package: "PluginThemePack", condition: .when(platforms: [.macOS])),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar", condition: .when(platforms: [.macOS])),
                .product(name: "ProviderCommand", package: "ProviderCommand", condition: .when(platforms: [.macOS])),
                .product(name: "ProviderLogo", package: "ProviderLogo", condition: .when(platforms: [.macOS])),
            ],
            path: "Sources/FactoryBookletMakerMac",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .target(
            name: "FactoryBookletMakerIOS",
            dependencies: [
                .product(name: "PluginBookletMaker", package: "PluginBookletMaker"),
            ],
            path: "Sources/FactoryBookletMakerIOS"
        ),
        .testTarget(
            name: "FactoryBookletMakerTests",
            dependencies: ["FactoryBookletMakerMac"],
            path: "Tests/FactoryBookletMakerTests"
        ),
    ]
)
