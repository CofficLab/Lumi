// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectOverview",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginProjectOverview",
            targets: ["ProjectOverviewPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../KitShell"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderPromptSuggestion"),
    ],
    targets: [
        .target(
            name: "ProjectOverviewPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitShell", package: "KitShell"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderPromptSuggestion", package: "ProviderPromptSuggestion"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ProjectOverviewPluginTests",
            dependencies: ["ProjectOverviewPlugin"],
            path: "Tests"
        )
    ]
)
