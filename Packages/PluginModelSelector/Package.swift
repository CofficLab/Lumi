// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginModelSelector",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginModelSelector", targets: ["PluginModelSelector"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderStorage"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderToast"),
    ],
    targets: [
        .target(
            name: "PluginModelSelector",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitLocalization",
                "LumiUI",
                "ProviderChatSection",
                "ProviderConversation",
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
