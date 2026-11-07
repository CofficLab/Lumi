// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSettingGeneral",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginSettingGeneral",
            targets: ["PluginSettingGeneral"]
        ),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../ProviderDiagnostics"),
        .package(path: "../KitLumiCLI"),
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiSettings"),
        .package(path: "../../Vendor/LumiLocalization"),
    ],
    targets: [
        .target(
            name: "PluginSettingGeneral",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderDiagnostics", package: "ProviderDiagnostics"),
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
