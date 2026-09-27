// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCommand",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginCommand", targets: ["PluginCommand"])],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.0.1"),
        .package(path: "../ProviderStorage"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginCommand",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderCommand", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginCommand",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "PluginCommandTests", dependencies: ["PluginCommand"]),
    ]
)
