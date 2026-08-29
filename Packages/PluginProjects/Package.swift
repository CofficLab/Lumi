// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjects",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginProjects", targets: ["PluginProjects"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(path: "../KernelCore"),
        .package(path: "../KitLLM"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderProjectRAG"),
        .package(path: "../ProviderSettingView"),
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
                "KernelCore",
                "KitLLM",
                "KitLocalization",
                "LumiUI",
                "ProviderProject",
                "ProviderProjectRAG",
                "ProviderSettingView",
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
                .product(name: "ProviderProject", package: "ProviderProject"),
            ]
        ),
    ]
)
