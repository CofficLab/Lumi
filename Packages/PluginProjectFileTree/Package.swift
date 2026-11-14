// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectFileTree",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginProjectFileTree", targets: ["PluginProjectFileTree"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(path: "../KitFileSystem"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
    ],
    targets: [
        .target(
            name: "PluginProjectFileTree",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderConversationInput", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
                "KitFileSystem",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginProjectFileTreeTests",
            dependencies: [
                .target(name: "PluginProjectFileTree"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
            ],
            path: "Tests"
        ),
    ]
)
