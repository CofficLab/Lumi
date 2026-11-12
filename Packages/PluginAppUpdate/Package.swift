// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppUpdate",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AppUpdatePlugin",
            targets: ["AppUpdatePlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1"),
        .package(path: "../KitTestSupport"),
    ],
    targets: [
        .target(
            name: "AppUpdatePlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderNetwork", package: "LumiProviders"),
                .product(name: "ProviderAppUpdate", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ],
            path: "Sources/PluginAppUpdate",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AppUpdatePluginTests",
            dependencies: [
                "AppUpdatePlugin",
                .product(name: "KitTestSupport", package: "KitTestSupport"),
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ],
            path: "Tests/AppUpdatePluginTests"
        )
    ]
)
