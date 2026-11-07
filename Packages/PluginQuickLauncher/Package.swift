// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginQuickLauncher",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginQuickLauncher",
            targets: ["QuickLauncherPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../../Vendor/LumiSettings"),
    ],
    targets: [
        .target(
            name: "QuickLauncherPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderCommand", package: "LumiProviders"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
            ],
            path: "Sources/PluginQuickLauncher",
            resources: [
                .process("../../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "QuickLauncherPluginTests",
            dependencies: ["QuickLauncherPlugin"],
            path: "Tests"
        )
    ]
)
