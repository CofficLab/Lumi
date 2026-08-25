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
        .package(path: "../AgentToolKit"),
        .package(path: "../KernelCore"),
        .package(path: "../KitLLM"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderPromptSuggestion"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginProjects",
            dependencies: [
                "AgentToolKit",
                "KernelCore",
                "KitLLM",
                "LocalizationKit",
                "LumiUI",
                "ProviderProject",
                "ProviderSettingView",
                "ProviderStorage",
                "ProviderToolbar",
                "ProviderToolManager",
                "ProviderPromptSuggestion",
                "ProviderLifecycleHooks",
                "SuperLogKit",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginProjectsTests",
            dependencies: ["PluginProjects"]
        ),
    ]
)
