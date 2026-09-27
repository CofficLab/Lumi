// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginQuickLauncher",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginQuickLauncher",
            targets: ["QuickLauncherPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.0.1"),
        .package(path: "../ProviderMessageSender"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(path: "../ProviderDocsView"),
    ],
    targets: [
        .target(
            name: "QuickLauncherPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderCommand", package: "LumiProviders"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "QuickLauncherPluginTests",
            dependencies: ["QuickLauncherPlugin"],
            path: "Tests"
        )
    ]
)
