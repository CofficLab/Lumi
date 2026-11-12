// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSettingGeneral",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginSettingGeneral",
            targets: ["PluginSettingGeneral"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(path: "../KitLumiCLI"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginSettingGeneral",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderDiagnostics", package: "LumiProviders"),
                .product(name: "ProviderUninstall", package: "LumiProviders"),
                .product(name: "ProviderCommand", package: "LumiProviders"),
                .product(name: "ProviderAppUpdate", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "KitLumiCLI", package: "KitLumiCLI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginSettingGeneral",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginSettingGeneralTests",
            dependencies: [
                "PluginSettingGeneral",
                .product(name: "KitLumiCLI", package: "KitLumiCLI"),
            ]
        )
    ]
)
