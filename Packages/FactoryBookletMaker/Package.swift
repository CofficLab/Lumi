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
        .package(url: "https://github.com/CofficLab/LumiThemePack.git", from: "1.0.3"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../PluginActivityBar"),
        .package(name: "PluginBookletMaker", path: "../PluginBookletMaker"),
        .package(path: "../PluginCommand"),
        .package(path: "../PluginLogoCoffic"),
        .package(path: "../PluginLogoManager"),
        .package(path: "../PluginSettingView"),
        .package(path: "../PluginStorage"),
        .package(path: "../PluginThemeManager"),
        .package(path: "../PluginThemePack"),
        .package(path: "../ProviderActivityBar"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.2"),
        .package(path: "../ProviderLogo"),
        .package(path: "../ProviderRootView"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "FactoryBookletMakerMac",
            dependencies: [
                .product(name: "LumiThemePack", package: "LumiThemePack"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "PluginBookletMaker", package: "PluginBookletMaker"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderTheme", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "PluginActivityBar", package: "PluginActivityBar", condition: .when(platforms: [.macOS])),
                .product(name: "PluginCommand", package: "PluginCommand", condition: .when(platforms: [.macOS])),
                .product(name: "PluginLogoCoffic", package: "PluginLogoCoffic", condition: .when(platforms: [.macOS])),
                .product(name: "PluginLogoManager", package: "PluginLogoManager", condition: .when(platforms: [.macOS])),
                .product(name: "PluginSettingView", package: "PluginSettingView", condition: .when(platforms: [.macOS])),
                .product(name: "PluginStorage", package: "PluginStorage", condition: .when(platforms: [.macOS])),
                .product(name: "PluginThemeManager", package: "PluginThemeManager", condition: .when(platforms: [.macOS])),
                .product(name: "PluginThemePack", package: "PluginThemePack", condition: .when(platforms: [.macOS])),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar", condition: .when(platforms: [.macOS])),
                .product(name: "ProviderCommand", package: "LumiProviders", condition: .when(platforms: [.macOS])),
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
