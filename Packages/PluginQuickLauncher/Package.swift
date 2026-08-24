// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginQuickLauncher",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginQuickLauncher",
            targets: ["QuickLauncherPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
        .package(path: "../ProviderCommand"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderSettingView"),
    ],
    targets: [
        .target(
            name: "QuickLauncherPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "ProviderCommand", package: "ProviderCommand"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
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
