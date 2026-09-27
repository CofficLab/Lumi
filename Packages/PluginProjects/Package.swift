// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjects",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginProjects", targets: ["PluginProjects"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitLLM"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(path: "../ProviderConversation"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderProjectRAG"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderPromptSuggestion"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginProjects",
            dependencies: [
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitLLM",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
                "ProviderConversation",
                "ProviderProject",
                "ProviderProjectRAG",
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                "ProviderStorage",
                "ProviderToolbar",
                "ProviderToolManager",
                "ProviderPromptSuggestion",
                "ProviderLifecycleHooks",
                "KitSuperLog",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginProjectsTests",
            dependencies: [
                "PluginProjects",
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
            ]
        ),
    ]
)
