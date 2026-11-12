// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginModelSelector",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginModelSelector", targets: ["PluginModelSelector"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderMessage"),
        .package(path: "../KitLLM"),
    ],
    targets: [
        .target(
            name: "PluginModelSelector",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderLLMManager",
                "ProviderMessage",
                .product(name: "ProviderStorage", package: "LumiProviders"),
                "KitLLM",
                .product(name: "ProviderToast", package: "LumiProviders"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginModelSelectorTests",
            dependencies: [
                "PluginModelSelector",
                "ProviderMessage",
            ]
        ),
    ]
)
