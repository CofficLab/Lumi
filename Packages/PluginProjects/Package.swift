// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjects",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginProjects", targets: ["PluginProjects"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../KitAgentTool"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../KitLLM"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../ProviderConversation"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../ProviderProjectRAG"),
        .package(path: "../../Vendor/LumiSettings"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../../Vendor/LumiLogging"),
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
                .product(name: "ProviderProject", package: "LumiProviders"),
                "ProviderProjectRAG",
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                "ProviderToolManager",
                .product(name: "ProviderPromptSuggestion", package: "LumiProviders"),
                "ProviderLifecycleHooks",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginProjectsTests",
            dependencies: [
                "PluginProjects",
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
            ]
        ),
    ]
)
