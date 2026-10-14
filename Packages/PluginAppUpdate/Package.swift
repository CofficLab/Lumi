// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppUpdate",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AppUpdatePlugin",
            targets: ["AppUpdatePlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.8.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0"),
    ],
    targets: [
        .target(
            name: "AppUpdatePlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderNetwork", package: "LumiProviders"),
                .product(name: "ProviderAppUpdate", package: "LumiProviders"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/PluginAppUpdate",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AppUpdatePluginTests",
            dependencies: ["AppUpdatePlugin"],
            path: "Tests/AppUpdatePluginTests"
        )
    ]
)
