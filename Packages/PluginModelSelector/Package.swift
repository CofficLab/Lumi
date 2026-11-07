// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginModelSelector",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "PluginModelSelector", targets: ["PluginModelSelector"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
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
