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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../ProviderNetwork"),
        .package(path: "../ProviderAppUpdate"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0"),
    ],
    targets: [
        .target(
            name: "AppUpdatePlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderNetwork", package: "ProviderNetwork"),
                .product(name: "ProviderAppUpdate", package: "ProviderAppUpdate"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources",
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
