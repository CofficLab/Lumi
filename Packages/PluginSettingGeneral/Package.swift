// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSettingGeneral",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginSettingGeneral",
            targets: ["PluginSettingGeneral"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderDiagnostics"),
        .package(path: "../ProviderUninstall"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.0.1"),
        .package(path: "../ProviderOnboarding"),
        .package(path: "../ProviderAppUpdate"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(path: "../ProviderStorage"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginSettingGeneral",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderDiagnostics", package: "ProviderDiagnostics"),
                .product(name: "ProviderUninstall", package: "ProviderUninstall"),
                .product(name: "ProviderCommand", package: "LumiProviders"),
                .product(name: "ProviderOnboarding", package: "ProviderOnboarding"),
                .product(name: "ProviderAppUpdate", package: "ProviderAppUpdate"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginSettingGeneral",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginSettingGeneralTests",
            dependencies: ["PluginSettingGeneral"]
        )
    ]
)
