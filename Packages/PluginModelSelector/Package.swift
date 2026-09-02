// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginModelSelector",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginModelSelector", targets: ["PluginModelSelector"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderStorage"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderToast"),
    ],
    targets: [
        .target(
            name: "PluginModelSelector",
            dependencies: [
                "KernelCore",
                "KitLocalization",
                "LumiUI",
                "ProviderChatSection",
                "ProviderLLMManager",
                "ProviderStorage",
                "KitLLM",
                "ProviderToast",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginModelSelectorTests",
            dependencies: ["PluginModelSelector"]
        ),
    ]
)
