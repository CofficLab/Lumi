// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInVSCode",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginOpenInVSCode", targets: ["PluginOpenInVSCode"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(path: "../KitOpenIn"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0")
    ],
    targets: [
        .target(
            name: "PluginOpenInVSCode",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "KitOpenIn",
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                "ProviderToolManager",
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ],
            path: "Sources/PluginOpenInVSCode",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginOpenInVSCodeTests",
            dependencies: [
                "PluginOpenInVSCode",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitOpenIn", package: "KitOpenIn"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ]
        ),
    ]
)
